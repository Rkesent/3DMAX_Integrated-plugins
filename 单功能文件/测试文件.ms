-- 检查缺少的外部文件并显示在UI中

-- 全局变量
global missingFiles = #()

-- 创建UI
rollout missingFilesRollout "缺少的外部文件"
(
    -- 列表视图
    dotNetControl lvMissingFiles "System.Windows.Forms.ListView" pos:[10,10] width:580 height:300
    
    -- 按钮
    button btnCheck "检查" pos:[10,320] width:100 height:40
    button btnClose "关闭" pos:[120,320] width:100 height:40
    button btnReplace "替换" pos:[230,320] width:100 height:40

    -- 初始化列表视图
    fn initListView =
    (
        lvMissingFiles.view = lvMissingFiles.View.Details
        lvMissingFiles.GridLines = true
        lvMissingFiles.FullRowSelect = true
        lvMissingFiles.MultiSelect = true
        lvMissingFiles.Columns.Clear()
        lvMissingFiles.Columns.Add "模型名称" 100
        lvMissingFiles.Columns.Add "材质" 100
        lvMissingFiles.Columns.Add "ID" 50
        lvMissingFiles.Columns.Add "文件名称" 250
    )

    -- 检查缺少的文件
    fn checkMissingFiles =
    (
        missingFiles = #() -- 清空之前的结果
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
                        local fileName = subMat.diffuseMap.filename
                        if fileName != "" and not doesFileExist fileName then
                        (
                            local fileBaseName = getFilenameFile fileName
                            local fileExtension = getFilenameType fileName
                            append missingFiles #(obj.name, subMat.name, i, fileBaseName + fileExtension)
                        )
                    )
                )
            )
            else if classof mat == Standardmaterial then
            (
                if mat.diffuseMap != undefined then
                (
                    local fileName = mat.diffuseMap.filename
                    if fileName != "" and not doesFileExist fileName then
                    (
                        local fileBaseName = getFilenameFile fileName
                        local fileExtension = getFilenameType fileName
                        append missingFiles #(obj.name, mat.name, 1, fileBaseName + fileExtension)
                    )
                )
            )
        )

        -- 更新UI
        lvMissingFiles.Items.Clear()
        for file in missingFiles do
        (
            local item = dotNetObject "System.Windows.Forms.ListViewItem" file[1]
            item.SubItems.Add file[2]
            item.SubItems.Add (file[3] as string)
            item.SubItems.Add file[4]
            lvMissingFiles.Items.Add item
        )

        if missingFiles.count == 0 then
        (
            messageBox "未找到缺少的外部文件。"
        )
    )

    -- 替换丢失的材质贴图
    fn replaceMissingFiles =
    (
        if missingFiles.count > 0 then
        (
            local newPath = getSavePath caption:"选择新的贴图路径"
            if newPath != undefined do
            (
                for file in missingFiles do
                (
                    local objName = file[1]
                    local matName = file[2]
                    local subMatIndex = file[3]
                    local originalFileName = file[4]

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
                            )
                        )
                        else if classof mat == Standardmaterial then
                        (
                            if mat.diffuseMap != undefined then
                            (
                                mat.diffuseMap.filename = newFilePath
                            )
                        )
                    )

                    -- 检查新路径中是否存在文件
                    if not doesFileExist newFilePath then
                    (
                        messageBox ("文件不存在: " + newFilePath)
                    )
                )
                messageBox "贴图路径已更新。"
            )
        )
        else
        (
            messageBox "没有需要替换的丢失文件。"
        )
    )

    -- 检查按钮点击事件
    on btnCheck pressed do
    (
        checkMissingFiles()
    )

    -- 关闭按钮点击事件
    on btnClose pressed do
    (
        closeRolloutFloater missingFilesFloater
    )

    -- 替换按钮点击事件
    on btnReplace pressed do
    (
        replaceMissingFiles()
    )

    -- 初始化
    on missingFilesRollout open do
    (
        initListView()
    )
)

-- 显示UI
try
(
    missingFilesFloater = newRolloutFloater "缺少的外部文件" 600 400
    addRollout missingFilesRollout missingFilesFloater
)
catch
(
    messageBox ("创建UI时发生错误：" + (getCurrentException()))
)
