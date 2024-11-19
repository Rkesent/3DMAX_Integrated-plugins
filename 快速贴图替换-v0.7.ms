-- 快速贴图替换.ms
-- 这个脚本用于查找和替换3ds Max场景中丢失的漫反射贴图

-- 全局变量
global missingMaps = #()

-- 自定义函数：检查数组中是否存在某个元素
fn arrayContains arr item =
(
    local found = false
    for i in arr where i == item do found = true
    found
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

    -- ID限制下拉框
    dotNetControl cmbIDLimit "System.Windows.Forms.ComboBox" pos:[340,370] width:60 height:40

    -- 按钮
    button btnCheck "检查" pos:[10,320] width:100 height:40
    button btnReplace "替换" pos:[120,320] width:100 height:40
    button btnChangePath "更换贴图路径" pos:[230,320] width:100 height:40
    button btnClearLog "清除日志" pos:[470,320] width:100 height:40
    
    -- 新增按钮
    button btnConvertToStandard "转化为标准材质" pos:[10,370] width:100 height:20
    button btnConvertToVR "转化为VR材质" pos:[10,390] width:100 height:20
    button btnRename "重命名" pos:[120,370] width:100 height:40
    button btnCheckModelID "模型ID数检查" pos:[230,370] width:100 height:40

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
                local idLimits = #(8, 16, 32, 64, 128)
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
        local col4 = lvModels.Columns.Add "丢失贴图名称" 130
        local col5 = lvModels.Columns.Add "错误信息" 100
        
        -- 设置列表总宽度以避免出现空列
        lvModels.width = 400  -- 调整总宽度为所有列宽之和
    )

    -- 检查缺少的文件
    fn checkMissingFiles =
    (
        local startTime = timestamp()
        missingMaps = #()
        local totalModels = geometry.count
        local totalMaps = 0
        local missingModelsCount = 0
        local missingMapsCount = 0
        local uniqueMissingMaps = #()
        local uniqueMissingModels = #()

        for obj in geometry where obj.material != undefined do
        (
            local mat = obj.material
            if classof mat == Multimaterial then
            (
                for i = 1 to mat.numsubs do
                (
                    local subMat = mat[i]
                    if subMat != undefined then
                    (
                        local diffuseMap = case classof subMat of
                        (
                            StandardMaterial: subMat.diffuseMap
                            VRayMtl: subMat.texmap_diffuse
                            PhysicalMaterial: subMat.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined then
                        (
                            totalMaps += 1
                            local fileName = diffuseMap.filename
                            if fileName != "" and not doesFileExist fileName then
                            (
                                local fileBaseName = getFilenameFile fileName
                                local fileExtension = getFilenameType fileName
                                append missingMaps #(obj.name, subMat.name, i, fileBaseName + fileExtension)
                                if not (arrayContains uniqueMissingMaps (fileBaseName + fileExtension)) then
                                (
                                    append uniqueMissingMaps (fileBaseName + fileExtension)
                                    missingMapsCount += 1
                                )
                                if not (arrayContains uniqueMissingModels obj.name) then
                                (
                                    append uniqueMissingModels obj.name
                                    missingModelsCount += 1
                                )
                            )
                        )
                    )
                )
            )
            else
            (
                local diffuseMap = case classof mat of
                (
                    StandardMaterial: mat.diffuseMap
                    VRayMtl: mat.texmap_diffuse
                    PhysicalMaterial: mat.base_color_map
                    default: undefined
                )
                
                if diffuseMap != undefined then
                (
                    totalMaps += 1
                    local fileName = diffuseMap.filename
                    if fileName != "" and not doesFileExist fileName then
                    (
                        local fileBaseName = getFilenameFile fileName
                        local fileExtension = getFilenameType fileName
                        append missingMaps #(obj.name, mat.name, 1, fileBaseName + fileExtension)
                        if not (arrayContains uniqueMissingMaps (fileBaseName + fileExtension)) then
                        (
                            append uniqueMissingMaps (fileBaseName + fileExtension)
                            missingMapsCount += 1
                        )
                        if not (arrayContains uniqueMissingModels obj.name) then
                        (
                            append uniqueMissingModels obj.name
                            missingModelsCount += 1
                        )
                    )
                )
            )
        )

        -- 更新UI
        lvModels.Items.Clear()
        for map in missingMaps do
        (
            local item = dotNetObject "System.Windows.Forms.ListViewItem" map[1]
            item.SubItems.Add map[2]
            item.SubItems.Add (map[3] as string)
            item.SubItems.Add map[4]
            local errorMsg = "贴图丢失"
            item.SubItems.Add errorMsg
            lvModels.Items.Add item
        )

        local endTime = timestamp()
        local elapsedTime = (endTime - startTime) / 1000.0

        local logMessage = ""
        if missingMaps.count == 0 then
        (
            logMessage += "------------------------ \r\n"
            logMessage += "未找到丢失的贴图。\r\n"
        )
        logMessage += "------------------------ \r\n"
        logMessage += "总模型数: " + totalModels as string + "个\r\n总贴图数: " + totalMaps as string + "张\r\n"
        logMessage += "丢失模型数: " + missingModelsCount as string + "个\r\n丢失贴图数: " + missingMapsCount as string + "张\r\n"
        logMessage += "检查\r\n耗时: " + elapsedTime as string + " 秒\r\n"
        logMessage += "###########$$$########## \r\n"

        insertLog logMessage
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
                local materialCount = if selectedObj.material != undefined then selectedObj.material.count else 0
                local quadFaceCount = 0

                if isKindOf selectedObj Editable_Poly then
                (
                    quadFaceCount = polyOp.getNumFaces selectedObj
                )
                else if isKindOf selectedObj Editable_Mesh then
                (
                    triFaceCount = selectedObj.numFaces
                )

                edtModelInfo.text = "名称: " + selectedObj.name + "\r\n材质ID数量: " + materialCount as string + "个\r\n四边面数量: " + quadFaceCount as string + "面"
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
    on btnCheck pressed do
    (
        checkMissingFiles()
    )

    -- 替换按钮点击事件
    on btnReplace pressed do
    (
        -- 先执行检查
        checkMissingFiles()
        
        -- 检查完成后，如果没有丢失的贴图则提示并返回
        if missingMaps.count == 0 then
        (
            messageBox "未检测到能替换的贴图！" title:"提示"
            return undefined
        )
        
        -- 如果有丢失的贴图，续执行替换操作
        local selectedFile = getOpenFileName caption:"选择替换贴图" types:"图像文件(*.jpg;*.png;*.tga)|*.jpg;*.png;*.tga|所有文件(*.*)|*.*|"
        if selectedFile != undefined do
        (
            local successCount = 0
            local failCount = 0
            
            for map in missingMaps do
            (
                local obj = getNodeByName map[1]
                if obj != undefined do
                (
                    local mat = obj.material
                    if classof mat == Multimaterial then
                    (
                        local subMat = mat[map[3]]
                        if subMat != undefined then
                        (
                            local diffuseMap = case classof subMat of
                            (
                                StandardMaterial: subMat.diffuseMap
                                VRayMtl: subMat.texmap_diffuse
                                PhysicalMaterial: subMat.base_color_map
                                default: undefined
                            )
                            if diffuseMap != undefined then
                            (
                                diffuseMap.filename = selectedFile
                                successCount += 1
                            )
                            else
                            (
                                failCount += 1
                            )
                        )
                        else
                        (
                            failCount += 1
                        )
                    )
                    else if classof mat == Standardmaterial then
                    (
                        if mat.diffuseMap != undefined then
                        (
                            mat.diffuseMap.filename = selectedFile
                            successCount += 1
                        )
                        else
                        (
                            failCount += 1
                        )
                    )
                )
            )

            local logMessage = "替换成功的模型数量: " + successCount as string + "\r\n"
            logMessage += "替换失败的模型数量: " + failCount as string + "\r\n"
            insertLog logMessage

            checkMissingFiles()
        )
    )

    -- 更换贴图路径按钮点击事件
    on btnChangePath pressed do
    (
        -- 先执行检查
        checkMissingFiles()
        
        -- 检查完成后，如果没有丢失的贴图则提示并返回
        if missingMaps.count == 0 then
        (
            messageBox "列表中未检测到丢失贴图的模型。" title:"提示"
            return undefined
        )
        
        -- 如果有丢失的贴图，继续执行更换路径操作
        local newPath = getSavePath caption:"择新的贴图路径"
        if newPath != undefined do
        (
            local startTime = timestamp()
            local missingFilesLog = ""
            local uniqueMissingMaps = #()
            local processedCount = 0
            
            for map in missingMaps do
            (
                local objName = map[1]
                local matName = map[2]
                local subMatIndex = map[3]
                local originalFileName = map[4]

                -- 获取文件名和后缀
                local fileBaseName = getFilenameFile originalFileName
                local fileExtension = getFilenameType originalFileName

                -- 新的完整文件路径
                local newFilePath = newPath + "\\" + fileBaseName + fileExtension

                -- 查找对象
                local obj = getNodeByName objName
                if obj != undefined and obj.material != undefined then
                (
                    local mat = obj.material
                    if classof mat == Multimaterial then
                    (
                        local subMat = mat[subMatIndex]
                        if subMat != undefined then
                        (
                            local diffuseMap = case classof subMat of
                            (
                                StandardMaterial: subMat.diffuseMap
                                VRayMtl: subMat.texmap_diffuse
                                PhysicalMaterial: subMat.base_color_map
                                default: undefined
                            )
                            if diffuseMap != undefined then
                            (
                                diffuseMap.filename = newFilePath
                                processedCount += 1
                            )
                        )
                    )
                    else if classof mat == Standardmaterial then
                    (
                        if mat.diffuseMap != undefined then
                        (
                            mat.diffuseMap.filename = newFilePath
                            processedCount += 1
                        )
                    )
                )

                -- 检查新路径中是否存在文件，只记录文件名
                if not doesFileExist newFilePath and not (arrayContains uniqueMissingMaps (fileBaseName + fileExtension)) then
                (
                    missingFilesLog += "文件不存在: " + (fileBaseName + fileExtension) + "\r\n"
                    append uniqueMissingMaps (fileBaseName + fileExtension)
                )
            )
            
            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0
            
            -- 确保所有变量都有值
            local logMessage = "------------------------ \r\n"
            logMessage += "处理完成\r\n"
            logMessage += "更新贴图数量: " + (processedCount as string) + "\r\n"
            logMessage += "耗时: " + (elapsedTime as string) + " 秒\r\n"
            logMessage += "------------------------ \r\n"
            logMessage += missingFilesLog -- 确保 missingFilesLog 有值
            insertLog logMessage

            messageBox "请等待3秒路径更新中。/n (点击确认后开始执行)"
        )
    )
    -- 递归函数，用于转换材质
    fn copyCommonProperties sourceMtl targetMtl =
    (
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

    fn convertMaterial mtl targetType =
    (
        try
        (
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
        catch
        (
            print ("Error converting material: " + (getCurrentException()))
            mtl -- 返回原始材质，如果转失败
        )
    )
    -- 清除日志按钮点击事件
    on btnClearLog pressed do
    (
        edtLog.Clear()
    )

    -- 转化为标准材质按钮点击事件
    on btnConvertToStandard pressed do
    (
        local startTime = timestamp()
        local totalCount = scenematerials.count
        local convertedCount = 0

        -- 遍历景中的所有材质
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
        logMessage += "转换为标准材质完成\r\n"
        logMessage += "总材质数: " + totalCount as string + "\r\n"
        logMessage += "转换材质数: " + convertedCount as string + "\r\n"
        logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
        logMessage += "<<暂时请勿操作:请等待2秒>>\r\n"
        logMessage += "------------------------ \r\n"
        insertLog logMessage
    )

    -- 转化为VR材质按钮点击事件
    on btnConvertToVR pressed do
    (
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
    )

    -- 添加重命名弹窗rollout
    rollout renameRollout "重命名工具" width:550 height:250
    (
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
        editText base1 "" pos:[20,55] width:60 height:20
        editText city1 "" pos:[100,55] width:60 height:20
        editText proj1 "" pos:[180,55] width:60 height:20
        editText abbr1 "" pos:[260,55] width:60 height:20
        spinner start1 "" pos:[340,55] width:40 height:30 range:[0,999,1] type:#integer scale:1
        
        -- 选择和填充位
        radioButtons rad1 "" pos:[20,80] width:150 height:20 labels:#("选择", "全部") columns:2
        label fill1 "填充位:" pos:[300,80] width:40 height:20 textColor:labelColor
        spinner fillNum1 "" pos:[340,80] width:40 height:30 range:[0,10,3] type:#integer scale:1
        
        -- 材质命名组
        GroupBox grp2 "材质命名" pos:[10,120] width:400 height:100    
        -- 材质命名标签行
        label lbl6 "基础代号" pos:[20,145] width:60 height:20 textColor:labelColor
        label plus5 "+" pos:[90,165] width:10 height:20 textColor:labelColor
        label lbl7 "城市名称" pos:[100,145] width:60 height:20 textColor:labelColor
        label plus6 "+" pos:[170,165] width:10 height:20 textColor:labelColor
        label lbl8 "项目名称" pos:[180,145] width:60 height:20 textColor:labelColor
        label plus7 "+" pos:[250,165] width:10 height:20 textColor:labelColor
        label lbl9 "姓名简写" pos:[260,145] width:60 height:20 textColor:labelColor
        label plus8 "+" pos:[330,165] width:10 height:20 textColor:labelColor
        label lbl10 "起始位" pos:[340,145] width:40 height:20 textColor:labelColor
        
        -- 材质命名输入框行
        editText base2 "" pos:[20,165] width:60 height:20
        editText city2 "" pos:[100,165] width:60 height:20
        editText proj2 "" pos:[180,165] width:60 height:20
        editText abbr2 "" pos:[260,165] width:60 height:20
        spinner start2 "" pos:[340,165] width:40 height:30 range:[0,999,1] type:#integer scale:1
        
        -- 选择和填充位
        radioButtons rad2 "" pos:[20,190] width:150 height:20 labels:#("选择", "全部") columns:2
        label fill2 "填充位:" pos:[300,190] width:40 height:20 textColor:labelColor
        spinner fillNum2 "" pos:[340,190] width:40 height:30 range:[0,10,3] type:#integer scale:1
        
        -- 右侧预览区域
        GroupBox previewGrp "命名预览" pos:[420,10] width:120 height:90
        editText preview "" pos:[430,30] width:100 height:60
        
        -- 底部按钮
        button renameBtn "重命名" pos:[420,110] width:120 height:30
        button useTextureBtn "将贴图名称作为材质名称" pos:[420,150] width:120 height:40

        -- 重命名按钮事件
        on renameBtn pressed do
        (
            -- 暂时只显示消息，具体重命名功能后续实现
            messageBox "重命名功能将在后续版本中实现" title:"提示"
            DestroyDialog renameRollout
        )

        -- 使用贴图名称按钮事件
        on useTextureBtn pressed do
        (
            -- 暂时只显示消息，具体功能后续实现
            messageBox "使用贴图名称功能将在后续版本中实现" title:"提示"
        )
    )

    -- 修改主界面中重命名按钮的事件处理程序
    on btnRename pressed do
    (
        try
        (
            -- 直接创建重命名弹窗，不检查选中状态
            createDialog renameRollout modal:true
        )
        catch
        (
            messageBox ("创建重命名窗口时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    on btnCheckModelID pressed do
    (
        local startTime = timestamp()
        
        -- 清空列表
        lvModels.Items.Clear()
        
        -- 获取选中的ID限制值
        if cmbIDLimit.SelectedItem != undefined then
        (
            local idLimit = cmbIDLimit.SelectedItem as integer
            -- 统计变量
            local totalModels = 0
            local totalMaterials = 0
            local abnormalModels = 0
            local overLimitModels = 0
            
            -- 遍历所有几何体
            for obj in geometry do
            (
                totalModels += 1
                local materialCount = 0
                local faceCount = 0
                local errorMsg = ""
                
                -- 获取面数
                if isKindOf obj Editable_Poly then
                    faceCount = polyOp.getNumFaces obj
                else if isKindOf obj Editable_Mesh then
                    faceCount = obj.numFaces
                    
                -- 检材质
                if obj.material != undefined then
                (
                    if classof obj.material == MultiMaterial then
                    (
                        materialCount = obj.material.numsubs
                        -- 检查材质ID是否超出限制
                        if materialCount > idLimit then
                        (
                            errorMsg = "超出ID限制"
                            overLimitModels += 1
                        )
                        -- 检查材质ID是否超出面数
                        else if materialCount > faceCount then
                            errorMsg = "材质ID数量过多"
                        else if materialCount < faceCount then
                            errorMsg = "材质ID数量未超过"
                    )
                    else
                    (
                        materialCount = 1
                    )
                    
                    totalMaterials += materialCount
                )
                else
                (
                    materialCount = 0
                    errorMsg = "无材质"
                )
                
                -- 如果有错误信息，则认为是异常模型
                if errorMsg != "" then
                    abnormalModels += 1
                    
                -- 添加到列表中
                local item = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                item.SubItems.Add (if obj.material != undefined then obj.material.name else "无材质")
                item.SubItems.Add (materialCount as string) -- ID数量列
                item.SubItems.Add "" -- 丢失贴图列保持为空
                item.SubItems.Add errorMsg
                
                -- 修改这部分：设置项目颜色
                if materialCount > idLimit then
                    item.ForeColor = (dotNetClass "System.Drawing.Color").Red
                else
                    item.ForeColor = (dotNetClass "System.Drawing.Color").Black -- 改为黑色
                
                lvModels.Items.Add item
            )
            
            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0
            
            -- 生成日志信息
            local logMessage = "------------------------ \r\n"
            logMessage += "模型ID检查完成\r\n"
            logMessage += "总模型数量: " + totalModels as string + "\r\n"
            logMessage += "总材质ID数: " + totalMaterials as string + "\r\n"
            logMessage += "异常模型数: " + abnormalModels as string + "\r\n"
            logMessage += "超出限制模型数: " + overLimitModels as string + "\r\n"
            logMessage += "ID限制: " + idLimit as string + "\r\n"
            logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
            logMessage += "------------------------ \r\n"
            
            -- 更新日志
            insertLog logMessage
        )
        else
        (
            messageBox "请先选择ID限制值！" title:"提示"
            return undefined
        )
    )

    -- 初始化
    on replaceMissingMapsRollout open do
    (
        try
        (
            initListView()
            initLogTextBox()
            initModelInfoTextBox()
            initIDLimitComboBox()
        )
        catch
        (
            messageBox ("初始化界面时发生错误：" + (getCurrentException())) title:"错误"
        )
    )
)

-- 显示UI
try
(
    createDialog replaceMissingMapsRollout width:640 height:420
)
catch
(
    messageBox ("创建UI时发生错误：" + (getCurrentException()))
)

