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

    -- 按钮
    button btnCheck "检查" pos:[10,320] width:100 height:40
    button btnReplace "替换" pos:[120,320] width:100 height:40
    button btnChangePath "更换贴图路径" pos:[230,320] width:100 height:40
    button btnClearLog "清除日志" pos:[470,320] width:100 height:40
    
    -- 新增按钮
    button btnConvertToStandard "转化为标准材质" pos:[10,370] width:100 height:20
    button btnConvertToVR "转化为VR材质" pos:[10,390] width:100 height:20

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

    -- 添加新的函数来插入日志
    fn insertLog message =
    (
        edtLog.Select 0 0
        edtLog.SelectedText = message + "\r\n" + edtLog.Text
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
        lvModels.Columns.Add "模型名称" 100
        lvModels.Columns.Add "材质" 100
        lvModels.Columns.Add "ID" 50
        lvModels.Columns.Add "丢失贴图名称" 130
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
                    if subMat != undefined and subMat.diffuseMap != undefined then
                    (
                        totalMaps += 1
                        local fileName = subMat.diffuseMap.filename
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
            else if classof mat == Standardmaterial then
            (
                if mat.diffuseMap != undefined then
                (
                    totalMaps += 1
                    local fileName = mat.diffuseMap.filename
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
        logMessage += "检查完毕\r\n耗时: " + elapsedTime as string + " 秒\r\n"
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
        local selectedFile = getOpenFileName caption:"选择替换贴图" types:"图像文件(*.jpg;*.png;*.tga)|*.jpg;*.png;*.tga|所有文件(*.*)|*.*|"
        if selectedFile != undefined do
        (
            local successCount = 0
            local failCount = 0
            
            if missingMaps.count > 0 then
            (
                for map in missingMaps do
                (
                    local obj = getNodeByName map[1]
                    if obj != undefined do
                    (
                        local mat = obj.material
                        if classof mat == Multimaterial then
                        (
                            local subMat = mat[map[3]]
                            if subMat != undefined and subMat.diffuseMap != undefined then
                            (
                                subMat.diffuseMap.filename = selectedFile
                                successCount += 1
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
            )
            else
            (
                messageBox "没有丢失的贴图需要替换。"
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
        if missingMaps.count > 0 then
        (
            local newPath = getSavePath caption:"选择新的贴图路径"
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
                            if subMat != undefined and subMat.diffuseMap != undefined then
                            (
                                subMat.diffuseMap.filename = newFilePath
                                processedCount += 1
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

                messageBox "请等待3秒路径更新中。"
            )
        )
        else
        (
            messageBox "没有需要更换路径的丢失文件。"
        )
    )
    -- 递归函数，用于转换材质
    fn copyCommonProperties sourceMtl targetMtl =
    (
        targetMtl.name = sourceMtl.name
        targetMtl.diffuse = sourceMtl.diffuse
        if sourceMtl.diffuseMap != undefined do targetMtl.diffuseMap = sourceMtl.diffuseMap
        -- 添加其他通用属性复制逻辑
    )

    fn convertMaterial mtl targetType =
    (
        if classof mtl == targetType then (
            return mtl -- 如果已经是目标类型，直接返回
        )
        else if classof mtl == VRayMtl and targetType == StandardMaterial then (
            newMtl = StandardMaterial()
            copyCommonProperties mtl newMtl
            return newMtl
        )
        else if classof mtl == StandardMaterial and targetType == VRayMtl then (
            newMtl = VRayMtl()
            copyCommonProperties mtl newMtl
            return newMtl
        )
        else if classof mtl == PhysicalMaterial and targetType == StandardMaterial then (
            newMtl = StandardMaterial()
            copyCommonProperties mtl newMtl
            return newMtl
        )
        else if classof mtl == MultiMaterial then (
            for i = 1 to mtl.numsubs do (
                mtl[i] = convertMaterial mtl[i] targetType
            )
            return mtl
        )
        else (
            return mtl
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
    local convertedCount = 0
    local totalCount = scenematerials.count

    -- 遍历场景中的所有材质
    for i = 1 to totalCount do (
        local oldMat = scenematerials[i]
        local newMat = convertMaterial oldMat StandardMaterial
        if newMat != undefined and newMat != oldMat then (
            scenematerials[i] = newMat
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
    local convertedCount = 0
    local totalCount = scenematerials.count

    -- 遍历场景中的所有材质
    for i = 1 to totalCount do (
        local oldMat = scenematerials[i]
        local newMat = convertMaterial oldMat VRayMtl
        if newMat != undefined and newMat != oldMat then (
            scenematerials[i] = newMat
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

    -- 初始化
    on replaceMissingMapsRollout open do
    (
        initListView()
        initLogTextBox()
        initModelInfoTextBox()
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

