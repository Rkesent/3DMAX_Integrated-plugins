-- 导出统一化工具.ms
-- 这个脚本用于查找和替换3ds Max场景中丢失的漫反射贴图
-- 如出现报错不能自己修改请联系作者：ly2552674305@163.com
-- 开源地址：https://github.com/Rkesent/3DMAX_Integrated-plugins
-- 可在上面网址更新脚本

-- 全局变量
global missingMaps = #()
global isProcessing = false

-- 新增：输入验证函数
fn trimAndValidateInput txt = (
    if txt == undefined then return false
    local trimmed = trimRight (trimLeft txt)
    trimmed != ""
)

-- 新增：序号生成函数
fn generateSequenceNumber num width = (
    try (
        -- 确保是有效数字
        local validNum = if num == undefined then 1 else num as integer
        -- 转换为字符串并填充
        local numStr = validNum as string
        while numStr.count < width do (
            numStr = "0" + numStr
        )
        return numStr
    ) catch (
        format "序号生成错误: %\n" (getCurrentException())
        return "001" -- 返回默认值
    )
)

-- 新增：对象重命名函数
fn renameObject obj newName = (
    try (
        if obj != undefined and isValidNode obj then (
            local oldName = obj.name
            obj.name = newName
            -- 验证重命名是否成功
            if obj.name != newName then (
                format "重命名失败: % -> %\n" oldName newName
                return false
            )
            return true
        )
        return false
    ) catch (
        format "重命名出错: %\n" (getCurrentException())
        return false
    )
)

-- 新增：批量重命名函数
fn renameModels baseCode cityName projName abbrName startNum fillCount objsToProcess = (
    local errorLog = stringStream ""
    local processedCount = 0
    local errorCount = 0
    
    try (
        -- 验证输入参数
        if baseCode == undefined or cityName == undefined or projName == undefined or 
           abbrName == undefined or startNum == undefined or fillCount == undefined then (
            format "参数无效\n" to:errorLog
            return #(0, 1, errorLog as string)
        )
        
        -- 当前序号
        local currentNum = startNum
        
        -- 处理每个对象
        for obj in objsToProcess do (
            try (
                if obj != undefined and isValidNode obj then (
                    -- 生成新名称
                    local numStr = formatNumberWithLeadingZeros currentNum fillCount
                    local newName = baseCode + "_" + cityName + "_" + projName + "_" + abbrName + "_" + numStr
                    
                    -- 尝试重命名
                    local oldName = obj.name
                    obj.name = newName
                    
                    -- 验证重命名是否成功
                    if obj.name == newName then (
                        processedCount += 1
                        currentNum += 1
                    ) else (
                        errorCount += 1
                        format "重命名失败: % -> %\n" oldName newName to:errorLog
                    )
                ) else (
                    errorCount += 1
                    format "无效对象\n" to:errorLog
                )
            ) catch (
                errorCount += 1
                format "处理对象时出错: %\n" (getCurrentException()) to:errorLog
            )
        )
        
        -- 返回结果
        local result = #(processedCount, errorCount, errorLog as string)
        
        -- 清理资源
        if errorLog != undefined do (
            try(free errorLog)catch()
            errorLog = undefined
        )
        gc light:true
        
        return result
    ) catch (
        -- 处理主要错误
        format "重命名过程出错: %\n" (getCurrentException()) to:errorLog
        
        -- 清理资源
        if errorLog != undefined do (
            try(free errorLog)catch()
            errorLog = undefined
        )
        gc light:true
        
        return #(0, 1, "重命名过程发生严重错误")
    )
)

-- 添加格式化数字的辅助函数
fn formatNumberWithLeadingZeros num width = (
    try (
        -- 确保输入值有效
        if num == undefined do num = 1
        if width == undefined do width = 3
        
        -- 转换为字符串并填充
        local numStr = num as string
        while numStr.count < width do (
            numStr = "0" + numStr
        )
        return numStr
    ) catch (
        -- 发生错误时返回默认值
        return "001"
    )
)

-- 添加必要的辅助函数
-- 获取材质的贴图名称
fn _getMapName _material = (
    try (
        _mapName = ""
        -- 检查材质是否为空
        if _material == undefined then return ""
        
        -- 检查diffuseMap
        if _material.diffuseMap != undefined then (
            if _material.diffuseMap.fileName != undefined then (
                _fileName = _material.diffuseMap.fileName
                _arr = filterString _fileName "\\"
                _mapName = (FilterString _arr[_arr.count] ".")[1]
                return _mapName
            )
        )
        
        -- 检查specularMap
        if _material.specularMap != undefined then (
            if _material.specularMap.fileName != undefined then (
                _fileName = _material.specularMap.fileName
                _arr = filterString _fileName "\\"
                _mapName = (FilterString _arr[_arr.count] ".")[1]
            )
        )
        return _mapName
    )
    catch (
        -- 发生错误时返回空字符串
        return ""
    )
)

-- 设置材质的名称和贴图名称
fn _setMaterialName _material = (
    try (
        -- 检查材质是否为空
        if _material == undefined then return false
        
        if(classof _material == MultiMaterial) then (
            matList = _material.MaterialList
            if matList != undefined and matList.count > 0 then (
                for m in matList where m != undefined do (
                    _setMaterialName m
                )
                _mapName = _getMapName matList[1]
                if _mapName != "" then (
                    _mapName = substring _mapName 2 -1
                    _material.name = "MATM" + _mapName
                )
            )
        )
        else (
            _mapName = _getMapName _material
            if(_mapName != "") then (
                _material.name = "MA" + _mapName
                if(_material.diffuseMap != undefined) then (
                    try(_material.diffuseMap.name = _mapName) catch()
                )
                if(_material.specularMap != undefined) then (
                    try(_material.specularMap.name = _mapName) catch()
                )
            )
            else (
                _material.name = "MAT"
            )
        )
        return true
    )
    catch (
        format "Error in _setMaterialName: %\n" (getCurrentException())
        return false
    )
)

-- 根据材质id获取面
fn _getFaceIDByMaterialID g id = (
    faceIDArr = #()
    allFace = polyOp.getNumFaces g
    for i = 1 to allFace do (
        faceMatID = polyOp.getFaceMatID g i
        if(faceMatID == id) then (
            append faceIDArr i
        )
    )
    return faceIDArr
)

-- 根据贴图名称查询材质数组中是否已经包含该贴图
fn getIndexByMapName matArr mapName = (
    index = 0
    for m = 1 to matArr.count do (
        _mapName = _getMapName matArr[m]
        if(mapName == _mapName) then (
            index = m
            exit
        )
    )
    return index
)

-- 根据diffuse颜色查询索引
fn getIndexByDiffuse matArr _color = (
    index = 0
    for m = 1 to matArr.count do (
        local color2 = case classof matArr[m] of (
            StandardMaterial: matArr[m].diffuse
            VRayMtl: matArr[m].diffuse
            PhysicalMaterial: matArr[m].base_color
            default: color 128 128 128 -- 默认灰色
        )
        if(_color == color2) then (
            index = m
            exit
        )
    )
    return index
)

-- 根据名称查询材质数组中是否已经包含该贴图的部分名称
fn includeByName matArr _name = (
    index = 0
    for m = 1 to matArr.count do (
        _mapName = _getMapName matArr[m]
        flog = findString _mapName _name
        if(flog != undefined) then (
            index = m
            exit
        )
    )
    return index
)

-- 将多维数组展开成一维
fn unfoldArr oldArr = (
    newArr = #()
    for i in oldArr do (
        if(classof i == Array) then (
            arr = unfoldArr i
            for j in arr do (
                append newArr j
            )
        )
        else (
            append newArr i
        )
    )
    return newArr
)

-- 优化材质
fn optimaizeMat geo = (
    mat = geo.material
    matIdList = mat.materialIDList
    matList = mat.materialList
    materialArr = #()
    faceArr = #()
    
    for index = 1 to matIdList.count do (
        matId = matIdList[index]
        mat = matList[index]
        face = _getFaceIDByMaterialID geo matId
        
        if(face.count == 0) then continue
        
        _mapName = _getMapName mat
        index = getIndexByMapName materialArr _mapName
        
        if(index == 0) then (
            index_gaojing = includeByName materialArr "高精贴片"
            isInclude = findString (_getMapName mat) "高精贴片"
            
            if(index_gaojing == 0 and isInclude != undefined) then (
                insertItem mat materialArr 1
                insertItem face faceArr 1
            )
            else (
                append materialArr mat
                append faceArr face
            )
        )
        else (
            if(_mapName == "") then (
                local color1 = case classof mat of (
                    StandardMaterial: mat.diffuse
                    VRayMtl: mat.diffuse
                    PhysicalMaterial: mat.base_color
                    default: color 128 128 128
                )
                __index = getIndexByDiffuse materialArr color1
                if(__index != 0) then (
                    append faceArr[__index] face
                )
                else (
                    append materialArr mat
                    append faceArr face
                )
            )
            else (
                append faceArr[index] face
            )
        )
    )
    
    -- 重新设置新的材质
    geo.material = Multimaterial numsubs:materialArr.count
    for index = 1 to faceArr.count do (
        faceArr[index] = unfoldArr faceArr[index]
        geo.material[index] = materialArr[index]
        polyOp.setFaceMatID geo faceArr[index] index
    )
)

-- 显示材质
fn displayMat = (
    local matArr = undefined
    
    try (
        matArr = #()
        -- 更新材质编辑器
        for me = 1 to meditMaterials.count do (
            meditMaterials[me] = Standardmaterial()
        )
        
        -- 收集材质
        for g in selection do (
            if((findItem matArr g.material) == 0) then (
                append matArr g.material
            )
        )
        
        -- 更新传统材质编辑器
        for m = 1 to matArr.count do (
            meditMaterials[m] = matArr[m]
        )
        
        -- 更新 Slate 材质编辑器
        if (sme.isOpen()) then (
            try(
                -- 清除现有视图
                sme.views[sme.activeView].ClearAll()
                
                -- 添加材质到 Slate 编辑器
                local posX = 100
                local posY = 100
                for mat in matArr do (
                    try(
                        -- 创建新节点
                        local newNode = sme.CreateMaterialNode mat [posX, posY]
                        posY += 150 -- 调整下一个材质的位置
                    )catch()
                )
                
                -- 重新布局视图
                sme.views[sme.activeView].ZoomToSelected()
                sme.views[sme.activeView].Redraw()
            )catch(
                format "Slate编辑器操作失败: %\n" (getCurrentException())
            )
        )
        
        -- 清理资源
        if matArr != undefined do (
            matArr = undefined
            gc light:true
        )
    ) catch (
        format "更新材质编辑器时出错: %\n" (getCurrentException())
        -- 清理资源
        if matArr != undefined do matArr = undefined
        gc light:true
    )
)

-- 自定义函数：检查数组中是否存在某个元素
fn arrayContains arr item =
(
    local found = false
    for i in arr where i == item do found = true
    found
)

-- 添加按钮状态管理函数
fn disableButton btn = (
    if btn != undefined do (
        btn.enabled = false
    )
)

fn enableButton btn = (
    if btn != undefined do (
        btn.enabled = true
    )
)

-- 创建UI
rollout replaceMissingMapsRollout "快速贴图替换"
(
    -- 主列表视图
    dotNetControl lvModels "System.Windows.Forms.ListView" pos:[10,10] width:400 height:300
    
    -- 模型详细信息区域
    groupBox grpModelInfo "模型详细信息" pos:[420,10] width:200 height:150
    dotNetControl edtModelInfo "System.Windows.Forms.TextBox" pos:[430,30] width:180 height:120
    
    -- 操作日志区域
    groupBox grpLog "操作日志" pos:[420,170] width:200 height:140
    dotNetControl edtLog "System.Windows.Forms.RichTextBox" pos:[430,190] width:180 height:110

    -- ID限制下拉框和标签
    label lblIDLimit "ID限制:" pos:[335,370] width:50 height:20
    dotNetControl cmbIDLimit "System.Windows.Forms.ComboBox" pos:[330,385] width:60 height:40

    -- 按钮
    button btnCheck "检查" pos:[10,320] width:100 height:40
    button btnReplace "替换" pos:[120,320] width:100 height:40
    button btnChangePath "更换贴图路径" pos:[230,320] width:100 height:40
    button btnClearLog "清除日志" pos:[470,320] width:100 height:40
    
    -- 新增按钮
    button btnConvertToStandard "转化为标准材质" pos:[10,370] width:100 height:20
    button btnConvertToVR "转化VR材质" pos:[10,390] width:100 height:20
    button btnRename "重命名" pos:[120,370] width:100 height:40
    button btnCheckModelID "模型ID数检查" pos:[230,370] width:100 height:40
    -- button btn_namemat "贴图命名材质" width:100 height:40 pos:[340,320]

    -- 添加函数声明
    fn insertLog message =
    (
        if edtLog != undefined do
        (
            edtLog.Select 0 0
            edtLog.SelectedText = message + "\r\n" + edtLog.Text
        )
    )

    -- 初始化函数
    fn initIDLimitComboBox =
    (
        try
        (
            if cmbIDLimit != undefined then
            (
                cmbIDLimit.Items.Clear()
                local idLimits = #(4, 8, 12, 20)
                for limit in idLimits do
                    cmbIDLimit.Items.Add (limit as string)
                cmbIDLimit.SelectedIndex = 2
                cmbIDLimit.DropDownStyle = cmbIDLimit.DropDownStyle.DropDownList
                cmbIDLimit.BackColor = (dotNetClass "System.Drawing.Color").White
                cmbIDLimit.ForeColor = (dotNetClass "System.Drawing.Color").Black
                cmbIDLimit.Font = dotNetObject "System.Drawing.Font" "Arial" 9
            )
        )
        catch
        (
            messageBox ("初始化ID限制下拉框时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    -- 初始化日志文本框
    fn initLogTextBox =
    (
        edtLog.Multiline = true
        edtLog.ReadOnly = true
        edtLog.BackColor = (dotNetClass "System.Drawing.Color").LightGray
        edtLog.Font = dotNetObject "System.Drawing.Font" "Arial" 9
        edtLog.WordWrap = true
        edtLog.ScrollBars = edtLog.ScrollBars.Vertical
    )

    -- 初始化模型详细信息文本框
    fn initModelInfoTextBox =
    (
        edtModelInfo.Multiline = true
        edtModelInfo.ReadOnly = true
        edtModelInfo.TextAlign = edtModelInfo.TextAlign.Left
        edtModelInfo.BackColor = (dotNetClass "System.Drawing.Color").LightGray
        edtModelInfo.BorderStyle = edtModelInfo.BorderStyle.None
    )

    -- 初始化列表视图
    fn initListView =
    (
        lvModels.view = lvModels.View.Details
        lvModels.GridLines = true
        lvModels.FullRowSelect = true
        lvModels.MultiSelect = true
        lvModels.Columns.Clear()
        
        -- 重新设置列宽和位置
        local col1 = lvModels.Columns.Add "模型名称" 100
        local col2 = lvModels.Columns.Add "材质" 100
        local col3 = lvModels.Columns.Add "ID" 50
        local col4 = lvModels.Columns.Add "丢失贴图名称" 120
        local col5 = lvModels.Columns.Add "错误信息" 100
        
        -- 设置列总宽度以避免出空列
        lvModels.width = 400  -- 调整总宽度为所有列宽之和
    )

    -- 检查缺少的文件
    fn checkMissingFiles = (
        local items = undefined
        local logMessage = undefined
        
        try (
            local startTime = timestamp()
            -- 清理之前的数组
            if missingMaps != undefined do (
                missingMaps = #()
                gc light:true
            )
            
            -- 清理ListView
            if lvModels != undefined do (
                lvModels.Items.Clear()
                -- 使用 BeginUpdate 替代 SuspendLayout
                lvModels.BeginUpdate()
            )
            
            local totalModels = geometry.count
            local totalMaps = 0
            local missingModelsCount = 0
            local missingMapsCount = 0
            local uniqueMissingMaps = #()
            local uniqueMissingModels = #()

            -- 使用for循环替代for...in以优化性能
            for i = 1 to geometry.count do (
                local obj = geometry[i]
                if obj.material != undefined do (
                    local mat = obj.material
                    if classof mat == Multimaterial then (
                        for i = 1 to mat.numsubs do (
                            local subMat = mat[i]
                            if subMat != undefined then (
                                local diffuseMap = case classof subMat of (
                                    StandardMaterial: subMat.diffuseMap
                                    VRayMtl: subMat.texmap_diffuse
                                    PhysicalMaterial: subMat.base_color_map
                                    default: undefined
                                )
                                
                                if diffuseMap != undefined then (
                                    totalMaps += 1
                                    local fileName = diffuseMap.filename
                                    if fileName != "" and not doesFileExist fileName then (
                                        local fileBaseName = getFilenameFile fileName
                                        local fileExtension = getFilenameType fileName
                                        append missingMaps #(obj.name, subMat.name, i, fileBaseName + fileExtension)
                                        
                                        -- 优化数组查找
                                        local mapKey = fileBaseName + fileExtension
                                        if findItem uniqueMissingMaps mapKey == 0 do (
                                            append uniqueMissingMaps mapKey
                                            missingMapsCount += 1
                                        )
                                        
                                        if findItem uniqueMissingModels obj.name == 0 do (
                                            append uniqueMissingModels obj.name
                                            missingModelsCount += 1
                                        )
                                    )
                                )
                            )
                        )
                    )
                    else (
                        local diffuseMap = case classof mat of (
                            StandardMaterial: mat.diffuseMap
                            VRayMtl: mat.texmap_diffuse
                            PhysicalMaterial: mat.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined then (
                            totalMaps += 1
                            local fileName = diffuseMap.filename
                            if fileName != "" and not doesFileExist fileName then (
                                local fileBaseName = getFilenameFile fileName
                                local fileExtension = getFilenameType fileName
                                append missingMaps #(obj.name, mat.name, 1, fileBaseName + fileExtension)
                                
                                -- 优化数组查找
                                local mapKey = fileBaseName + fileExtension
                                if findItem uniqueMissingMaps mapKey == 0 do (
                                    append uniqueMissingMaps mapKey
                                    missingMapsCount += 1
                                )
                                
                                if findItem uniqueMissingModels obj.name == 0 do (
                                    append uniqueMissingModels obj.name
                                    missingModelsCount += 1
                                )
                            )
                        )
                    )
                )
            )

            -- 批量更新UI
            if lvModels != undefined do (
                local items = dotNetObject "System.Windows.Forms.ListViewItem[]" missingMaps.count
                for i = 1 to missingMaps.count do (
                    local map = missingMaps[i]
                    local item = dotNetObject "System.Windows.Forms.ListViewItem" map[1]
                    item.SubItems.Add map[2]
                    item.SubItems.Add (map[3] as string)
                    item.SubItems.Add map[4]
                    item.SubItems.Add "贴图丢失"
                    items[i-1] = item
                )
                lvModels.Items.AddRange items
                -- 使用 EndUpdate 替代 ResumeLayout
                lvModels.EndUpdate()
            )

            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0

            -- 生成日志信息
            logMessage = stringStream ""
            format "------------------------ \r\n" to:logMessage
            if missingMaps.count == 0 then (
                format "未找到丢失的贴图。\r\n" to:logMessage
            )
            format "总模型数: %个\r\n总贴图数: %张\r\n" totalModels totalMaps to:logMessage
            format "丢失模型数: %个\r\n丢失贴图数: %张\r\n" missingModelsCount missingMapsCount to:logMessage
            format "检查耗时: % 秒\r\n" elapsedTime to:logMessage
            format "###########$$$########## \r\n" to:logMessage

            insertLog (logMessage as string)
            
            -- 清理临时变量
            if items != undefined do items = undefined
            if logMessage != undefined do (
                try(free logMessage)catch()
                logMessage = undefined
            )
            gc light:true
            uniqueMissingMaps = undefined
            uniqueMissingModels = undefined
        ) catch (
            messageBox ("检查贴图时发生错误：" + (getCurrentException())) title:"错误"
            -- 确保发生错误时也能释放资源
            if lvModels != undefined do (
                lvModels.EndUpdate()
            )
            -- 清理临时变量
            if items != undefined do items = undefined
            if logMessage != undefined do (
                try(free logMessage)catch()
                logMessage = undefined
            )
            gc light:true
        )
    )

    -- 列表项点击事件
    on lvModels ItemSelectionChanged s e do
    (
        if e.IsSelected then
        (
            local selectedObj = getNodeByName e.Item.Text
            if selectedObj != undefined then
            (
                select selectedObj
                local materialCount = 0
                if selectedObj.material != undefined then
                (
                    if classof selectedObj.material == MultiMaterial then
                        materialCount = selectedObj.material.numsubs
                    else
                        materialCount = 1
                )
                
                local quadFaceCount = 0

                if isKindOf selectedObj Editable_Poly then
                (
                    quadFaceCount = polyOp.getNumFaces selectedObj
                )
                else if isKindOf selectedObj Editable_Mesh then
                (
                    triFaceCount = selectedObj.numFaces
                )

                edtModelInfo.text = "名: " + selectedObj.name + "\r\n材质ID数量: " + materialCount as string + "个\r\n四边面数量: " + quadFaceCount as string + "面"
            )
        )
    )

    -- 列表项双击事件
    on lvModels DoubleClick s e do
    (
        local selectedObj = getNodeByName (lvModels.SelectedItems.Item[0].Text)
        if selectedObj != undefined then
        (
            max zoomext sel all
        )
    )

    -- 检查按钮点击事件
    on btnCheck pressed do (
        if isProcessing do return()
        isProcessing = true
        disableButton btnCheck
        try (
            checkMissingFiles()
        ) catch (
            messageBox ("检查贴图时发生错误：" + (getCurrentException())) title:"错误"
        )
        isProcessing = false
        enableButton btnCheck
    )

    -- 替换按钮点击事件
    on btnReplace pressed do (
        try (
            -- 禁用按钮防止重复点击
            disableButton btnReplace
            
            -- 临时变量声明
            local selectedFile = undefined
            local successCount = 0
            local failCount = 0
            
            -- 检查是否有选中的项目
            if lvModels.SelectedItems.Count > 0 then (
                selectedFile = getOpenFileName caption:"选择替换贴图" types:"图像文件(*.jpg;*.png;*.tga)|*.jpg;*.png;*.tga|所有文件(*.*)|*.*|"
                if selectedFile != undefined do (
                    -- 遍历选中的项目
                    for i = 0 to lvModels.SelectedItems.Count - 1 do (
                        try (
                            local selectedItem = lvModels.SelectedItems.Item[i]
                            local objName = selectedItem.Text
                            local matName = selectedItem.SubItems.Item[1].Text
                            local matID = try(selectedItem.SubItems.Item[2].Text as integer)catch(1)
                            
                            -- 获取对象
                            local obj = getNodeByName objName
                            if obj != undefined do (
                                local mat = obj.material
                                if classof mat == Multimaterial then (
                                    -- 处理多重材质
                                    if matID > 0 and matID <= mat.numsubs then (
                                        local subMat = mat[matID]
                                        if subMat != undefined then (
                                            local diffuseMap = case classof subMat of (
                                                StandardMaterial: subMat.diffuseMap
                                                VRayMtl: subMat.texmap_diffuse
                                                PhysicalMaterial: subMat.base_color_map
                                                default: undefined
                                            )
                                            
                                            if diffuseMap != undefined then (
                                                diffuseMap.filename = selectedFile
                                                successCount += 1
                                            ) else failCount += 1
                                        ) else failCount += 1
                                    ) else failCount += 1
                                ) else (
                                    -- 处理单一材质
                                    local diffuseMap = case classof mat of (
                                        StandardMaterial: mat.diffuseMap
                                        VRayMtl: mat.texmap_diffuse
                                        PhysicalMaterial: mat.base_color_map
                                        default: undefined
                                    )
                                    
                                    if diffuseMap != undefined then (
                                        diffuseMap.filename = selectedFile
                                        successCount += 1
                                    ) else failCount += 1
                                )
                            )
                        ) catch (
                            failCount += 1
                            format "处理对象时出错: %\n" (getCurrentException())
                        )
                    )
                )
            ) else (
                -- 如果没有选中项，则检查所有丢失的贴图
                checkMissingFiles()
                
                -- 检查完成后，如果没有丢失的贴图则提示并返回
                if missingMaps.count == 0 then (
                    messageBox "未检测到能替换的贴图！" title:"提示"
                    return undefined
                )
                
                selectedFile = getOpenFileName caption:"选择替换贴图" types:"图像文件(*.jpg;*.png;*.tga)|*.jpg;*.png;*.tga|所有文件(*.*)|*.*|"
                if selectedFile != undefined do (
                    -- 使用临时数组存储需要处理的对象，避免直接使用全局变量
                    local mapsToProcess = #()
                    join mapsToProcess missingMaps
                    
                    for map in mapsToProcess do (
                        try (
                            local obj = getNodeByName map[1]
                            if obj != undefined do (
                                local mat = obj.material
                                if classof mat == Multimaterial then (
                                    local subMat = mat[map[3]]
                                    if subMat != undefined then (
                                        local diffuseMap = case classof subMat of (
                                            StandardMaterial: subMat.diffuseMap
                                            VRayMtl: subMat.texmap_diffuse
                                            PhysicalMaterial: subMat.base_color_map
                                            default: undefined
                                        )
                                        
                                        if diffuseMap != undefined then (
                                            diffuseMap.filename = selectedFile
                                            successCount += 1
                                        ) else failCount += 1
                                    ) else failCount += 1
                                ) else (
                                    local diffuseMap = case classof mat of (
                                        StandardMaterial: mat.diffuseMap
                                        VRayMtl: mat.texmap_diffuse
                                        PhysicalMaterial: mat.base_color_map
                                        default: undefined
                                    )
                                    
                                    if diffuseMap != undefined then (
                                        diffuseMap.filename = selectedFile
                                        successCount += 1
                                    ) else failCount += 1
                                )
                            )
                        ) catch (
                            failCount += 1
                            format "处理对象时出错: %\n" (getCurrentException())
                        )
                    )
                    
                    -- 清理临时数组
                    mapsToProcess = undefined
                )
            )
            
            -- 生成日志信息
            if selectedFile != undefined do (
                local logMessage = "------------------------ \r\n"
                logMessage += "替换完成\r\n"
                logMessage += "成功替换: " + successCount as string + "个\r\n"
                if failCount > 0 then (
                    logMessage += "替换失败: " + failCount as string + "个\r\n"
                )
                logMessage += "------------------------ \r\n"
                insertLog logMessage
                
                -- 刷新检查结果
                checkMissingFiles()
            )
            
            -- 清理资源
            selectedFile = undefined
            gc light:true
            
        ) catch (
            messageBox ("替换贴图时发生错误：" + (getCurrentException())) title:"错误"
        )
        
        -- 重新启用按钮
        enableButton btnReplace
    )

    -- 更换贴图路径按钮点击事件
    on btnChangePath pressed do (
        try (
            -- 禁用按钮，防止重复点击
            disableButton btnChangePath
            
            -- 如果有选中项，只处理选中的项目
            local itemsToProcess = if lvModels.SelectedItems.Count > 0 then (
                -- 收集选中项的信息
                for i = 0 to lvModels.SelectedItems.Count - 1 collect (
                    local item = lvModels.SelectedItems.Item[i]
                    #(item.Text, item.SubItems.Item[1].Text, try(item.SubItems.Item[2].Text as integer)catch(1))
                )
            ) else (
                -- 没有选中项时执行检查
                checkMissingFiles()
                missingMaps
            )
            
            -- 检查是否有需要处理的项目
            if itemsToProcess.count == 0 then (
                messageBox "列表中未检测到丢失贴图的模型。" title:"提示"
                enableButton btnChangePath
                return undefined
            )
            
            -- 选择新路径
            local newPath = getSavePath caption:"选择新的贴图路径"
            if newPath != undefined do (
                local startTime = timestamp()
                local processedCount = 0
                local failedCount = 0
                local uniquePaths = #() -- 用于存储已处理的路径
                local pathUpdates = #() -- 预处理：收集所有需要更新的贴图路径
                
                -- 使用 with redraw off 来减少重绘
                with redraw off (
                    -- 批量处理所有对象
                    for itemInfo in itemsToProcess do (
                        local obj = getNodeByName itemInfo[1]
                        if obj != undefined and obj.material != undefined then (
                            local mat = obj.material
                            
                            if classof mat == MultiMaterial then (
                                -- 处理多重材质
                                local matID = itemInfo[3]
                                if matID > 0 and matID <= mat.numsubs then (
                                    local subMat = mat[matID]
                                    if subMat != undefined then (
                                        local diffuseMap = case classof subMat of (
                                            StandardMaterial: subMat.diffuseMap
                                            VRayMtl: subMat.texmap_diffuse
                                            PhysicalMaterial: subMat.base_color_map
                                            default: undefined
                                        )
                                        
                                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                            local currentPath = diffuseMap.filename
                                            local fileName = filenameFromPath currentPath
                                            local newFilePath = newPath + "\\" + fileName
                                            append pathUpdates #(diffuseMap, currentPath, newFilePath)
                                        )
                                    )
                                )
                            ) else (
                                -- 处理单一材质
                                local diffuseMap = case classof mat of (
                                    StandardMaterial: mat.diffuseMap
                                    VRayMtl: mat.texmap_diffuse
                                    PhysicalMaterial: mat.base_color_map
                                    default: undefined
                                )
                                
                                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                    local currentPath = diffuseMap.filename
                                    local fileName = filenameFromPath currentPath
                                    local newFilePath = newPath + "\\" + fileName
                                    append pathUpdates #(diffuseMap, currentPath, newFilePath)
                                )
                            )
                        )
                    )
                    
                    -- 批量更新贴图路径
                    for update in pathUpdates do (
                        try (
                            local diffuseMap = update[1]
                            local oldPath = update[2]
                            local newFilePath = update[3]
                            
                            -- 检查是否已处理过该路径
                            if findItem uniquePaths oldPath == 0 then (
                                append uniquePaths oldPath
                                -- 复制文件（如果需要）
                                if doesFileExist oldPath and not doesFileExist newFilePath then (
                                    try(copyFile oldPath newFilePath)catch()
                                )
                            )
                            
                            -- 更新贴图路径
                            diffuseMap.filename = newFilePath
                            processedCount += 1
                        ) catch (
                            failedCount += 1
                        )
                    )
                )
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = "------------------------ \r\n"
                logMessage += "路径更新完成\r\n"
                logMessage += "处理贴图数: " + processedCount as string + "\r\n"
                if failedCount > 0 then (
                    logMessage += "失败数量: " + failedCount as string + "\r\n"
                )
                logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                logMessage += "------------------------ \r\n"
                insertLog logMessage
                
                -- 刷新检查结果
                checkMissingFiles()
            )
        ) catch (
            messageBox ("更换贴图路径时发生错误：" + (getCurrentException())) title:"错误"
        )
        
        -- 重新启用按钮
        enableButton btnChangePath
    )

    -- 递归函数，用于转材质
    fn copyCommonProperties sourceMtl targetMtl = (
        targetMtl.name = sourceMtl.name
        
        -- 处理 diffuse 颜色
        case classof sourceMtl of
        (
            StandardMaterial: (
                if (classof targetMtl == StandardMaterial) then targetMtl.diffuse = sourceMtl.diffuse
                else if (classof targetMtl == VRayMtl) then targetMtl.diffuse = sourceMtl.diffuse
                else if (classof targetMtl == PhysicalMaterial) then targetMtl.base_color = sourceMtl.diffuse
            )
            VRayMtl: (
                if (classof targetMtl == StandardMaterial) then targetMtl.diffuse = sourceMtl.diffuse
                else if (classof targetMtl == VRayMtl) then targetMtl.diffuse = sourceMtl.diffuse
                else if (classof targetMtl == PhysicalMaterial) then targetMtl.base_color = sourceMtl.diffuse
            )
            PhysicalMaterial: (
                if (classof targetMtl == StandardMaterial) then targetMtl.diffuse = sourceMtl.base_color
                else if (classof targetMtl == VRayMtl) then targetMtl.diffuse = sourceMtl.base_color
                else if (classof targetMtl == PhysicalMaterial) then targetMtl.base_color = sourceMtl.base_color
            )
        )
        
        -- 处理贴图
        local sourceMap = case classof sourceMtl of
        (
            StandardMaterial: sourceMtl.diffuseMap
            VRayMtl: sourceMtl.texmap_diffuse
            PhysicalMaterial: sourceMtl.base_color_map
            default: undefined
        )
        
        if sourceMap != undefined do
        (
            case classof targetMtl of
            (
                StandardMaterial: targetMtl.diffuseMap = sourceMap
                VRayMtl: targetMtl.texmap_diffuse = sourceMap
                PhysicalMaterial: targetMtl.base_color_map = sourceMap
            )
        )
        -- 可以根据需要添加更多通用属性的复制
    )

    fn convertMaterial mtl targetType = (
        try (
            case classof mtl of
            (
                StandardMaterial: (
                    if targetType == VRayMtl then
                    (
                        newMtl = VRayMtl()
                        copyCommonProperties mtl newMtl
                        newMtl
                    )
                    else mtl
                )
                VRayMtl: (
                    if targetType == StandardMaterial then
                    (
                        newMtl = StandardMaterial()
                        copyCommonProperties mtl newMtl
                        newMtl
                    )
                    else mtl
                )
                PhysicalMaterial: (
                    if targetType == StandardMaterial then
                    (
                        newMtl = StandardMaterial()
                        copyCommonProperties mtl newMtl
                        newMtl
                    )
                    else if targetType == VRayMtl then
                    (
                        newMtl = VRayMtl()
                        copyCommonProperties mtl newMtl
                        newMtl
                    )
                    else mtl
                )
                MultiMaterial: (
                    for i = 1 to mtl.numsubs do
                    (
                        mtl[i] = convertMaterial mtl[i] targetType
                    )
                    mtl
                )
                default: mtl
            )
        )
        catch (
            print ("Error converting material: " + (getCurrentException()))
            mtl -- 返回原始材质，如果转失败
        )
    )
    -- 清除日志按钮点击事件
    on btnClearLog pressed do (
        edtLog.Clear()
    )

    -- 转化为标准材质按钮点击事件
    on btnConvertToStandard pressed do (
        if isProcessing do return()
        isProcessing = true
        disableButton btnConvertToStandard
        try (
            local startTime = timestamp()
            local totalCount = scenematerials.count
            local convertedCount = 0

            -- 遍历场景的所有材质
            for i = 1 to totalCount do
            (
                local oldMat = scenematerials[i]
                local newMat = convertMaterial oldMat StandardMaterial
                if newMat != oldMat then
                (
                    replaceInstances oldMat newMat
                    convertedCount += 1
                )
            )

            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0

            local logMessage = "------------------------ \r\n"
            logMessage += "转换标准材质完成\r\n"
            logMessage += "总材质数: " + totalCount as string + "\r\n"
            logMessage += "转换材质数: " + convertedCount as string + "\r\n"
            logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
            logMessage += "<<暂时请勿操作:请等待2秒>>\r\n"
            logMessage += "------------------------ \r\n"
            insertLog logMessage
        ) catch (
            messageBox ("转换质时发生错误：" + (getCurrentException())) title:"错误"
        )
        isProcessing = false
        enableButton btnConvertToStandard
    )

    -- 转化为VR材质按钮点击事件
    on btnConvertToVR pressed do (
        if isProcessing do return()
        isProcessing = true
        disableButton btnConvertToVR
        try (
            local startTime = timestamp()
            local totalCount = scenematerials.count
            local convertedCount = 0

            -- 遍历场景中的所有材质
            for i = 1 to totalCount do
            (
                local oldMat = scenematerials[i]
                local newMat = convertMaterial oldMat VRayMtl
                if newMat != oldMat then
                (
                    replaceInstances oldMat newMat
                    convertedCount += 1
                )
            )

            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0

            local logMessage = "------------------------ \r\n"
            logMessage += "转换为VR材质完成\r\n"
            logMessage += "总材质数: " + totalCount as string + "\r\n"
            logMessage += "转换材质数: " + convertedCount as string + "\r\n"
            logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
            logMessage += "<<暂时请勿操作:请等待2秒>>\r\n"
            logMessage += "------------------------ \r\n"
            insertLog logMessage
        ) catch (
            messageBox ("转换材质时发生错误：" + (getCurrentException())) title:"错误"
        )
        isProcessing = false
        enableButton btnConvertToVR
    )

    -- 添加重命名弹窗rollout
    rollout renameRollout "重命名工具" width:550 height:250
    (
        local closeTimer = undefined
        
        -- 添加计时器创建函数
        fn createCloseTimer = (
            if closeTimer != undefined then (
                try(closeTimer.Dispose())catch()
            )
            closeTimer = dotNetObject "System.Windows.Forms.Timer"
            closeTimer.Interval = 1000 -- 1秒
            closeTimer.Tick += dotNetObject "System.EventHandler" closeTimer (
                fn timerCallback sender args = (
                    try(
                        sender.Stop()
                        destroyDialog renameRollout
                        sender.Dispose()
                    )catch()
                )
            )
            closeTimer
        )

        local labelColor = (color 180 180 180) -- 标签文字颜色

        -- 模型命名组
        GroupBox grp1 "模型命名" pos:[10,10] width:400 height:100
        
        -- 模型命名标签行
        label lbl1 "基础代号" pos:[20,35] width:60 height:20 textColor:labelColor
        label plus1 "+" pos:[90,60] width:10 height:10 textColor:labelColor 
        label lbl2 "城市名称" pos:[100,35] width:60 height:20 textColor:labelColor
        label plus2 "+" pos:[170,60] width:10 height:10 textColor:labelColor 
        label lbl3 "项目名称" pos:[180,35] width:60 height:20 textColor:labelColor
        label plus3 "+" pos:[250,60] width:10 height:10 textColor:labelColor 
        label lbl4 "姓名简写" pos:[260,35] width:60 height:20 textColor:labelColor
        label plus4 "+" pos:[330,60] width:10 height:10 textColor:labelColor
        label lbl5 "起始位" pos:[340,35] width:40 height:20 textColor:labelColor
        
        -- 模型命名输入框行
        editText base1 "" pos:[20,55] width:60 height:20 text:"SM" align:#center
        editText city1 "" pos:[100,55] width:60 height:20 align:#center
        editText proj1 "" pos:[180,55] width:60 height:20 align:#center
        editText abbr1 "" pos:[260,55] width:60 height:20 align:#center
        spinner start1 "" pos:[340,55] width:40 height:30 range:[0,999,1] type:#integer scale:1
        
        -- 选择和填充位
        radioButtons rad1 "" pos:[20,80] width:150 height:20 labels:#("选择", "全部") columns:2
        label fill1 "填充位:" pos:[300,80] width:40 height:20 textColor:labelColor
        spinner fillNum1 "" pos:[340,80] width:40 height:30 range:[0,10,3] type:#integer scale:1
        checkbox chk_enableRename "启用模型命名" pos:[160,80] width:90 height:20
        
        -- 贴图命名组
        GroupBox grp2 "贴图命名" pos:[10,120] width:400 height:100    
        -- 贴图命名标签行
        label lbl6 "基础代号" pos:[20,145] width:60 height:20 textColor:labelColor
        label plus5 "+" pos:[90,165] width:10 height:20 textColor:labelColor
        label lbl7 "城市名称" pos:[100,145] width:60 height:20 textColor:labelColor
        label plus6 "+" pos:[170,165] width:10 height:20 textColor:labelColor
        label lbl8 "项目名称" pos:[180,145] width:60 height:20 textColor:labelColor
        label plus7 "+" pos:[250,165] width:10 height:20 textColor:labelColor
        label lbl9 "姓名简写" pos:[260,145] width:60 height:20 textColor:labelColor
        label plus8 "+" pos:[330,165] width:10 height:20 textColor:labelColor
        label lbl10 "起始位" pos:[340,145] width:40 height:20 textColor:labelColor
        
        -- 贴图命名输入框行
        editText base2 "" pos:[20,165] width:60 height:20 text:"T" align:#center
        editText city2 "" pos:[100,165] width:60 height:20 align:#center
        editText proj2 "" pos:[180,165] width:60 height:20 align:#center
        editText abbr2 "" pos:[260,165] width:60 height:20 align:#center
        spinner start2 "" pos:[340,165] width:40 height:30 range:[0,999,1] type:#integer scale:1
        
        -- 选择和填充位
        radioButtons rad2 "" pos:[20,190] width:150 height:20 labels:#("选择", "全部") columns:2
        label fill2 "填充位:" pos:[300,190] width:40 height:20 textColor:labelColor
        spinner fillNum2 "" pos:[340,190] width:40 height:30 range:[0,10,3] type:#integer scale:1
        checkbox chk_enableTextureRename "启用贴图命名" pos:[160,190] width:90 height:20 checked:false
        
        -- 底部按钮
        button renameBtn "重命名" pos:[420,15] width:120 height:30
        button useTextureBtn "将贴图名称作为材质名称" pos:[420,50] width:120 height:40
        checkBox chkArchive "将贴图归档" pos:[440,90] width:80 height:20

        -- 重命名按钮事件
        on renameBtn pressed do (
            try (
                local hasValidOperation = false
                
                -- 检查模型重命名功能
                if chk_enableRename.checked then (
                    -- 检查必填字段是否为空
                    if (trimAndValidateInput base1.text) and 
                       (trimAndValidateInput city1.text) and 
                       (trimAndValidateInput proj1.text) and 
                       (trimAndValidateInput abbr1.text) then (
                        hasValidOperation = true
                        local startTime = timestamp()
                        
                        -- 获取输入值并确保它们都有效
                        local baseCode = trimRight (trimLeft base1.text)
                        local cityName = trimRight (trimLeft city1.text)
                        local projName = trimRight (trimLeft proj1.text)
                        local abbrName = trimRight (trimLeft abbr1.text)
                        local startNum = try(start1.value as integer)catch(1)
                        local fillCount = try(fillNum1.value as integer)catch(3)
                        
                        -- 获取要处理的对象数组
                        local objsToProcess = #()
                        if rad1.state == 1 then (
                            objsToProcess = selection as array
                            if objsToProcess.count == 0 then (
                                messageBox "请先选择要重命名的对象！" title:"提示"
                                return undefined
                            )
                        ) else (
                            for obj in geometry where (not obj.isHidden and isValidNode obj) do (
                                append objsToProcess obj
                            )
                            if objsToProcess.count == 0 then (
                                messageBox "场景中没有可处理的对象！" title:"错误"
                                return undefined
                            )
                        )
                        
                        -- 执行重命名
                        local result = renameModels baseCode cityName projName abbrName startNum fillCount objsToProcess
                        
                        local endTime = timestamp()
                        local elapsedTime = (endTime - startTime) / 1000.0
                        
                        -- 生成日志信息
                        local logMessage = "------------------------ \r\n"
                        logMessage += "模型重命名完成\r\n"
                        logMessage += "成功处理: " + result[1] as string + "个\r\n"
                        if result[2] > 0 then (
                            logMessage += "失败数量: " + result[2] as string + "个\r\n"
                            logMessage += "错误信息:\n" + result[3]
                        )
                        logMessage += "起始序号: " + startNum as string + "\r\n"
                        logMessage += "填充位数: " + fillCount as string + "\r\n"
                        logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                        logMessage += "------------------------ \r\n"
                        
                        -- 更新日志
                        insertLog logMessage
                    )
                    else (
                        messageBox "请填写所有模型命名相关的字段！" title:"提示"
                        return undefined
                    )
                )
                
                -- 贴图重命名功能
                if chk_enableTextureRename.checked then (
                    -- 检查必填字段是否为空
                    if base2.text != "" and city2.text != "" and proj2.text != "" and abbr2.text != "" then (
                        hasValidOperation = true
                        local startTime = timestamp()
                        local processedCount = 0
                        
                        -- 获取输入值并确保它们都有效
                        local baseCode = base2.text
                        local cityName = city2.text
                        local projName = proj2.text
                        local abbrName = abbr2.text
                        local startNumber = try(start2.value as integer)catch(1)
                        local fillWidth = try(fillNum2.value as integer)catch(3)
                        
                        -- 获取要处理的对象数组
                        local objsToProcess = #()
                        if rad2.state == 1 then (
                            objsToProcess = selection as array
                            if objsToProcess.count == 0 then (
                                messageBox "请先选择要处理的对象！" title:"提示"
                                return undefined
                            )
                        ) else (
                            for obj in geometry where not obj.isHidden do (
                                append objsToProcess obj
                            )
                        )
                        
                        -- 用于记录所有贴图的重命名映射
                        local allRenameMappings = #()
                        local currentNumber = startNumber
                        
                        -- 第一步：如果勾选了归档选项，先执行归档操作
                        if chkArchive.checked then (
                            local mapPathMapping = archiveMapFiles objsToProcess
                            if mapPathMapping.count == 0 then (
                                messageBox "归档贴图失败，请确保场景已保存且贴图文件可访问！" title:"错误"
                                return undefined
                            )
                            
                            -- 第二步：更新场景中的贴图路径
                            for mapping in mapPathMapping do (
                                local oldPath = mapping[1]
                                local newPath = mapping[2]
                                
                                -- 更新所有使用该贴图的材质
                                for obj in objsToProcess do (
                                    if obj.material != undefined then (
                                        if classof obj.material == MultiMaterial then (
                                            for i = 1 to obj.material.numsubs do (
                                                local subMat = obj.material[i]
                                                if subMat != undefined then (
                                                    local diffuseMap = case classof subMat of (
                                                        StandardMaterial: subMat.diffuseMap
                                                        VRayMtl: subMat.texmap_diffuse
                                                        PhysicalMaterial: subMat.base_color_map
                                                        default: undefined
                                                    )
                                                    
                                                    if diffuseMap != undefined and diffuseMap.filename == oldPath then (
                                                        diffuseMap.filename = newPath
                                                    )
                                                )
                                            )
                                        ) else (
                                            local diffuseMap = case classof obj.material of (
                                                StandardMaterial: obj.material.diffuseMap
                                                VRayMtl: obj.material.texmap_diffuse
                                                PhysicalMaterial: obj.material.base_color_map
                                                default: undefined
                                            )
                                            
                                            if diffuseMap != undefined and diffuseMap.filename == oldPath then (
                                                diffuseMap.filename = newPath
                                            )
                                        )
                                    )
                                )
                            )
                        )
                        
                        -- 第三步：收集所有需要重命名的贴图
                        for obj in objsToProcess do (
                            local result = processTextureRename obj currentNumber fillWidth baseCode cityName projName abbrName
                            local objMappings = result[1]
                            currentNumber = result[2]
                            join allRenameMappings objMappings
                        )
                        
                        -- 第四步：执行重命名操作
                        for mapping in allRenameMappings do (
                            try (
                                local oldPath = mapping[1]
                                local newPath = mapping[2]
                                
                                -- 重命名文件
                                if doesFileExist oldPath then (
                                    renameFile oldPath newPath
                                    
                                    -- 更新所有使用该贴图的材质的路径
                                    for obj in objsToProcess do (
                                        if obj.material != undefined then (
                                            if classof obj.material == MultiMaterial then (
                                                for i = 1 to obj.material.numsubs do (
                                                    local subMat = obj.material[i]
                                                    if subMat != undefined then (
                                                        local diffuseMap = case classof subMat of (
                                                            StandardMaterial: subMat.diffuseMap
                                                            VRayMtl: subMat.texmap_diffuse
                                                            PhysicalMaterial: subMat.base_color_map
                                                            default: undefined
                                                        )
                                                        
                                                        if diffuseMap != undefined and diffuseMap.filename == oldPath then (
                                                            diffuseMap.filename = newPath
                                                        )
                                                    )
                                                )
                                            ) else (
                                                local diffuseMap = case classof obj.material of (
                                                    StandardMaterial: obj.material.diffuseMap
                                                    VRayMtl: obj.material.texmap_diffuse
                                                    PhysicalMaterial: obj.material.base_color_map
                                                    default: undefined
                                                )
                                                
                                                if diffuseMap != undefined and diffuseMap.filename == oldPath then (
                                                    diffuseMap.filename = newPath
                                                )
                                            )
                                        )
                                    )
                                    
                                    processedCount += 1
                                )
                            ) catch (
                                format "重命名文件时出错: %\n" (getCurrentException())
                                continue
                            )
                        )
                        
                        local endTime = timestamp()
                        local elapsedTime = (endTime - startTime) / 1000.0
                        
                        -- 生成日志信息
                        local logMessage = "------------------------ \r\n"
                        logMessage += "贴图处理完成\r\n"
                        if chkArchive.checked then (
                            logMessage += "已归档贴图数: " + (if mapPathMapping != undefined then mapPathMapping.count else 0) as string + "\r\n"
                        )
                        logMessage += "重命名贴图数: " + processedCount as string + "\r\n"
                        logMessage += "起始序号: " + startNumber as string + "\r\n"
                        logMessage += "填充位数: " + fillWidth as string + "\r\n"
                        logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                        logMessage += "------------------------ \r\n"
                        
                        -- 更新日志
                        insertLog logMessage
                    )
                    else (
                        messageBox "请填写所有贴图命名相关的字段！" title:"提示"
                        return undefined
                    )
                )
                
                -- 如果两个功能都未启用，显示提示
                if not hasValidOperation then (
                    messageBox "请至少启用一个命名功能并填写相关字段！" title:"提示"
                    return undefined
                )
                
                -- 成功执行后关闭窗口
                if hasValidOperation then (
                    try(
                        local timer = createCloseTimer()
                        timer.Start()
                    )catch(
                        try(destroyDialog renameRollout)catch()
                    )
                )
            )
            catch (
                messageBox ("重命名过程中发生错误：" + (getCurrentException())) title:"错误"
            )
        )

        -- 使用贴图名称按钮事件
        on useTextureBtn pressed do (
            try (
                local startTime = timestamp()
                local processedCount = 0
                local errorCount = 0
                local emptyMatCount = 0
                
                -- 获取当前选中的对象
                local selObjects = selection as array
                if selObjects.count == 0 then (
                    messageBox "请先选择要处理的模型！" title:"提示"
                    return undefined
                )
                
                -- 清空主窗口的列表
                if replaceMissingMapsRollout.lvModels != undefined do (
                    replaceMissingMapsRollout.lvModels.Items.Clear()
                )
                
                for item in selObjects do (
                    if item.material != undefined then (
                        if (classof item.material == Multimaterial) then (
                            try (
                                local hasEmptyMat = false
                                -- 检查多重材质中是否有空材质
                                for i = 1 to item.material.numsubs do (
                                    if item.material[i] == undefined then (
                                        -- 添加到列表中
                                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" item.name
                                        listItem.SubItems.Add "多重材质"
                                        listItem.SubItems.Add (i as string)
                                        listItem.SubItems.Add ""
                                        listItem.SubItems.Add "材质ID " + i as string + " 为空"
                                        listItem.ForeColor = (dotNetClass "System.Drawing.Color").Red
                                        replaceMissingMapsRollout.lvModels.Items.Add listItem
                                        
                                        hasEmptyMat = true
                                        emptyMatCount += 1
                                    )
                                )
                                
                                -- 如果没有材质，则进行命名
                                if not hasEmptyMat then (
                                    -- 优化材质
                                    optimaizeMat item
                                    if(_setMaterialName item.material) then (
                                        item.material.name = "MAT_" + substring item.name 4 item.name.count
                                        processedCount += 1
                                    )
                                    else (
                                        errorCount += 1
                                    )
                                )
                            ) catch (
                                errorCount += 1
                                format "Error processing multimaterial: %\n" (getCurrentException())
                            )
                        )
                        else (
                            if(_setMaterialName item.material) then (
                                processedCount += 1
                            )
                            else (
                                errorCount += 1
                            )
                        )
                    )
                    else (
                        -- 添加无材质的物体到列表
                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" item.name
                        listItem.SubItems.Add "无材质"
                        listItem.SubItems.Add "0"
                        listItem.SubItems.Add ""
                        listItem.SubItems.Add "物体无材质"
                        listItem.ForeColor = (dotNetClass "System.Drawing.Color").Red
                        replaceMissingMapsRollout.lvModels.Items.Add listItem
                        emptyMatCount += 1
                    )
                )
                
                try(displayMat()) catch()
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = "------------------------ \r\n"
                logMessage += "材质命名完成\r\n"
                logMessage += "成功处理材质数: " + processedCount as string + "\r\n"
                if errorCount > 0 then (
                    logMessage += "处理失败数: " + errorCount as string + "\r\n"
                )
                if emptyMatCount > 0 then (
                    logMessage += "空材质/无材质数: " + emptyMatCount as string + "\r\n"
                )
                logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                logMessage += "------------------------ \r\n"
                
                -- 更新日志
                insertLog logMessage
                
                -- 使用计时器关闭窗口
                try(
                    local timer = createCloseTimer()
                    timer.Start()
                )catch(
                    try(destroyDialog renameRollout)catch()
                )
            )
            catch (
                messageBox ("处理材质命名时发生错误：" + (getCurrentException())) title:"错误"
            )
        )

        -- 在 renameRollout 中添加关闭事件处理
        on renameRollout close do (
            try(
                -- 清理计时器
                if closeTimer != undefined then (
                    closeTimer.Stop()
                    closeTimer.Dispose()
                    closeTimer = undefined
                )
                
                -- 清理其他资源
                base1.text = ""
                city1.text = ""
                proj1.text = ""
                abbr1.text = ""
                base2.text = ""
                city2.text = ""
                proj2.text = ""
                abbr2.text = ""
                
                -- 强制垃圾回收
                gc()
                gc light:true
            )catch()
        )
    )

    -- 添加贴图归档函数
    fn archiveMapFile sourceFile = (
        try (
            -- 获取当前场景文件路径
            local scenePath = maxFilePath
            if scenePath == "" then (
                messageBox "请先保存场景文件！" title:"提示"
                return false
            )
            
            -- 创建maps文夹
            local mapsDir = pathConfig.appendPath scenePath "maps"
            makeDir mapsDir
            
            -- 获取源文件名
            local fileName = filenameFromPath sourceFile
            
            -- 构建目标文件路径
            local targetFile = pathConfig.appendPath mapsDir fileName
            
            -- 复制文件
            if doesFileExist sourceFile then (
                copyFile sourceFile targetFile
                return true
            )
            return false
        ) catch (
            format "归档贴图出错: %\n" (getCurrentException())
            return false
        )
    )

    -- 修改主界面中重命名按钮的事件处理程序
    on btnRename pressed do (
        try (
            -- 创建非模态对话框
            createDialog renameRollout modal:false
        )
        catch (
            messageBox ("创建重命名窗口时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    on btnCheckModelID pressed do (
        if isProcessing do return()
        isProcessing = true
        disableButton btnCheckModelID
        try (
            local startTime = timestamp()
            
            -- 清空列表并暂停更新
            if lvModels != undefined do (
                lvModels.Items.Clear()
                lvModels.BeginUpdate()
            )
            
            if cmbIDLimit.SelectedItem != undefined then (
                local idLimit = cmbIDLimit.SelectedItem as integer
                local totalModels = 0
                local totalMaterials = 0
                local abnormalModels = 0
                local overLimitModels = 0
                
                -- 创建临时数组存储列表项
                local items = #()
                
                -- 遍历几何体
                for obj in geometry do (
                    totalModels += 1
                    local materialCount = 0
                    local faceCount = 0
                    local errorMsg = ""
                    
                    -- 获取面数
                    if isKindOf obj Editable_Poly then
                        faceCount = polyOp.getNumFaces obj
                    else if isKindOf obj Editable_Mesh then
                        faceCount = obj.numFaces
                        
                    -- 检查材质
                    if obj.material != undefined then (
                        if classof obj.material == MultiMaterial then (
                            materialCount = obj.material.numsubs
                            if materialCount > idLimit then (
                                errorMsg = "超出ID限制"
                                overLimitModels += 1
                            )
                            else if materialCount > faceCount then
                                errorMsg = "材质ID数量过多"
                            else if materialCount < faceCount then
                                errorMsg = "材ID数量未超过"
                        )
                        else
                            materialCount = 1
                        
                        totalMaterials += materialCount
                    )
                    else (
                        materialCount = 0
                        errorMsg = "无材质"
                    )
                    
                    if errorMsg != "" then
                        abnormalModels += 1
                    
                    -- 创建列表项
                    local item = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                    item.SubItems.Add (if obj.material != undefined then obj.material.name else "无材质")
                    item.SubItems.Add (materialCount as string)
                    item.SubItems.Add ""
                    item.SubItems.Add errorMsg
                    
                    if materialCount > idLimit then
                        item.ForeColor = (dotNetClass "System.Drawing.Color").Red
                    else
                        item.ForeColor = (dotNetClass "System.Drawing.Color").Black
                    
                    append items item
                )
                
                -- 批量添加列表项
                local itemsArray = dotNetObject "System.Windows.Forms.ListViewItem[]" items.count
                for i = 1 to items.count do (
                    itemsArray[i-1] = items[i]
                )
                lvModels.Items.AddRange itemsArray
                
                -- 恢复ListView更新
                lvModels.EndUpdate()
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = stringStream ""
                format "------------------------ \r\n" to:logMessage
                format "模型ID检查完成\r\n" to:logMessage
                format "总模型数量: %个\r\n总材质ID数: %个\r\n" totalModels totalMaterials to:logMessage
                format "异常模型数: %个\r\n超出限制模型数: %个\r\n" abnormalModels overLimitModels to:logMessage
                format "ID限制: %个\r\n" idLimit to:logMessage
                format "耗时: % 秒\r\n" elapsedTime to:logMessage
                format "------------------------ \r\n" to:logMessage
                
                insertLog (logMessage as string)
                
                -- 清理资源
                free logMessage
                items = undefined
                gc light:true
            )
            else (
                messageBox "请先选择ID限制值！" title:"提示"
            )
        ) catch (
            messageBox ("检查模型ID时发生错误：" + (getCurrentException())) title:"错误"
        )
        isProcessing = false
        enableButton btnCheckModelID
    )

    -- 初始化
    on replaceMissingMapsRollout open do (
        try (
            initListView()
            initLogTextBox()
            initModelInfoTextBox()
            initIDLimitComboBox()
        )
        catch (
            messageBox ("初始化界面时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    -- 在 replaceMissingMapsRollout rollout 中添加 setMaterial 函数
    fn setMaterial = (
        local startTime = timestamp()
        local processedCount = 0
        local errorCount = 0
        local emptyMatCount = 0
        
        -- 清空列表
        lvModels.Items.Clear()
        
        for item in selection do (
            if item.material != undefined then (
                if (classof item.material == Multimaterial) then (
                    try (
                        local hasEmptyMat = false
                        -- 检查多重材质中是否有空材质
                        for i = 1 to item.material.numsubs do (
                            if item.material[i] == undefined then (
                                -- 添加到列表中
                                local listItem = dotNetObject "System.Windows.Forms.ListViewItem" item.name
                                listItem.SubItems.Add "多重材质"
                                listItem.SubItems.Add (i as string)
                                listItem.SubItems.Add ""
                                listItem.SubItems.Add "材质ID " + i as string + " 为空"
                                listItem.ForeColor = (dotNetClass "System.Drawing.Color").Red
                                lvModels.Items.Add listItem
                                
                                hasEmptyMat = true
                                emptyMatCount += 1
                            )
                        )
                        
                        -- 如果没有空材质，则进行命名
                        if not hasEmptyMat then (
                            -- 优化材质
                            optimaizeMat item
                            if(_setMaterialName item.material) then (
                                item.material.name = "MAT_" + substring item.name 4 item.name.count
                                processedCount += 1
                            )
                            else (
                                errorCount += 1
                            )
                        )
                    ) catch (
                        errorCount += 1
                        format "Error processing multimaterial: %\n" (getCurrentException())
                    )
                )
                else (
                    if(_setMaterialName item.material) then (
                        processedCount += 1
                    )
                    else (
                        errorCount += 1
                    )
                )
            )
            else (
                -- 添加无材质的物体到列表
                local listItem = dotNetObject "System.Windows.Forms.ListViewItem" item.name
                listItem.SubItems.Add "无材质"
                listItem.SubItems.Add "0"
                listItem.SubItems.Add ""
                listItem.SubItems.Add "物体无材质"
                listItem.ForeColor = (dotNetClass "System.Drawing.Color").Red
                lvModels.Items.Add listItem
                emptyMatCount += 1
            )
        )
        
        try(displayMat()) catch()
        
        local endTime = timestamp()
        local elapsedTime = (endTime - startTime) / 1000.0
        
        -- 生成日志信息
        local logMessage = "------------------------ \r\n"
        logMessage += "材质命名完成\r\n"
        logMessage += "成功处理材质数: " + processedCount as string + "\r\n"
        if errorCount > 0 then (
            logMessage += "处理失败数: " + errorCount as string + "\r\n"
        )
        if emptyMatCount > 0 then (
            logMessage += "空材质/无材质数: " + emptyMatCount as string + "\r\n"
        )
        logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
        logMessage += "------------------------ \r\n"
        
        -- 更新日志
        insertLog logMessage
    )

    -- 修改贴图命名材质按钮的事件处理程序
    on btn_namemat pressed do (
        if selection.count == 0 then
        (
            messageBox "请先选择要处理的模型！" title:"提示"
            return undefined
        )
        
        setMaterial()
    )
)

-- 显示UI
try (
    createDialog replaceMissingMapsRollout width:640 height:420
)
catch (
    messageBox ("创建UI时发生错误：" + (getCurrentException()))
)

-- 在 archiveMapFile 函数后添加新的 archiveMapFiles 函数
fn archiveMapFiles objsToProcess = (
    local mapPathMapping = undefined
    
    try (
        mapPathMapping = #()
        -- 获取当前场景文件路径
        local scenePath = maxFilePath
        if scenePath == "" then (
            messageBox "请先保存场景文件！" title:"提示"
            return #()
        )
        
        -- 创建maps文件夹
        local mapsDir = pathConfig.appendPath scenePath "maps"
        makeDir mapsDir
        
        -- 收集并复制所有贴图
        for obj in objsToProcess do (
            if obj.material != undefined then (
                if classof obj.material == MultiMaterial then (
                    for i = 1 to obj.material.numsubs do (
                        local subMat = obj.material[i]
                        if subMat != undefined then (
                            local diffuseMap = case classof subMat of (
                                StandardMaterial: subMat.diffuseMap
                                VRayMtl: subMat.texmap_diffuse
                                PhysicalMaterial: subMat.base_color_map
                                default: undefined
                            )
                            
                            if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                local oldPath = diffuseMap.filename
                                if findItem (for m in mapPathMapping collect m[1]) oldPath == 0 then (
                                    -- 获取文件名
                                    local fileName = filenameFromPath oldPath
                                    -- 构建新路径
                                    local newPath = pathConfig.appendPath mapsDir fileName
                                    
                                    -- 复制文件
                                    if doesFileExist oldPath then (
                                        copyFile oldPath newPath
                                        -- 更新材质的贴图路径
                                        diffuseMap.filename = newPath
                                        append mapPathMapping #(oldPath, newPath)
                                    )
                                )
                            )
                        )
                    )
                ) else (
                    local diffuseMap = case classof obj.material of (
                        StandardMaterial: obj.material.diffuseMap
                        VRayMtl: obj.material.texmap_diffuse
                        PhysicalMaterial: obj.material.base_color_map
                        default: undefined
                    )
                    
                    if diffuseMap != undefined and diffuseMap.filename != undefined then (
                        local oldPath = diffuseMap.filename
                        if findItem (for m in mapPathMapping collect m[1]) oldPath == 0 then (
                            -- 获取文件名
                            local fileName = filenameFromPath oldPath
                            -- 构建新路径
                            local newPath = pathConfig.appendPath mapsDir fileName
                            
                            -- 复制文件
                            if doesFileExist oldPath then (
                                copyFile oldPath newPath
                                -- 更新材质的贴图路径
                                diffuseMap.filename = newPath
                                append mapPathMapping #(oldPath, newPath)
                            )
                        )
                    )
                )
            )
        )
        
        -- 清理资源
        local result = mapPathMapping
        mapPathMapping = undefined
        gc light:true
        return result
    ) catch (
        format "归档贴图出错: %\n" (getCurrentException())
        -- 清理资源
        if mapPathMapping != undefined do mapPathMapping = undefined
        gc light:true
        return #()
    )
)

-- 修改数字填充函数，使用更安全的方式处理数字
fn formatNumberWithLeadingZeros num width = (
    try (
        -- 确保输入值有效
        if num == undefined do num = 1
        if width == undefined do width = 3
        
        -- 转换为字符串并填充
        local numStr = num as string
        while numStr.count < width do (
            numStr = "0" + numStr
        )
        return numStr
    ) catch (
        -- 发生错误时返回默认值
        return "001"
    )
)

-- 修改重命名函数
fn processTextureRename obj startNumber fillWidth baseCode cityName projName abbrName = (
    local renameMappings = #()
    local currentNumber = startNumber
    
    try (
        if obj.material != undefined then (
            if classof obj.material == MultiMaterial then (
                -- 处理多重材质
                for i = 1 to obj.material.numsubs do (
                    local subMat = obj.material[i]
                    if subMat != undefined then (
                        -- 获取贴图
                        local diffuseMap = case classof subMat of (
                            StandardMaterial: subMat.diffuseMap
                            VRayMtl: subMat.texmap_diffuse
                            PhysicalMaterial: subMat.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                            local oldPath = diffuseMap.filename
                            if doesFileExist oldPath then (
                                -- 生成新的贴图名称
                                local fileDir = getFilenamePath oldPath
                                local fileExt = getFilenameType oldPath
                                local numStr = formatNumberWithLeadingZeros currentNumber fillWidth
                                local newFileName = baseCode + "_" + cityName + "_" + projName + "_" + abbrName + "_" + numStr + fileExt
                                local newPath = fileDir + newFileName
                                
                                -- 添加到重命名映射列表
                                if findItem (for m in renameMappings collect m[1]) oldPath == 0 then (
                                    append renameMappings #(oldPath, newPath)
                                    currentNumber += 1
                                )
                            )
                        )
                    )
                )
            ) else (
                -- 处理单一材质
                local diffuseMap = case classof obj.material of (
                    StandardMaterial: obj.material.diffuseMap
                    VRayMtl: obj.material.texmap_diffuse
                    PhysicalMaterial: obj.material.base_color_map
                    default: undefined
                )
                
                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                    local oldPath = diffuseMap.filename
                    if doesFileExist oldPath then (
                        -- 生成新的贴图名称
                        local fileDir = getFilenamePath oldPath
                        local fileExt = getFilenameType oldPath
                        local numStr = formatNumberWithLeadingZeros currentNumber fillWidth
                        local newFileName = baseCode + "_" + cityName + "_" + projName + "_" + abbrName + "_" + numStr + fileExt
                        local newPath = fileDir + newFileName
                        
                        -- 添加到重命名映射列表
                        if findItem (for m in renameMappings collect m[1]) oldPath == 0 then (
                            append renameMappings #(oldPath, newPath)
                            currentNumber += 1
                        )
                    )
                )
            )
        )
        
        -- 返回重命名映射和当前序号
        return #(renameMappings, currentNumber)
    ) catch (
        format "处理贴图重命名时出错: %\n" (getCurrentException())
        return #(#(), startNumber)
    )
)
