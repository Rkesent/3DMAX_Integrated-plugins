-- 快速贴图替换.ms
-- 这个脚本用于查找和替换3ds Max场景中丢失的漫反射贴图

-- 全局变量
global missingMaps = #()

-- 创建UI
rollout replaceMissingMapsRollout "快速贴图替换"
(
    -- 主列表视图
    dotNetControl lvModels "System.Windows.Forms.ListView" pos:[10,10] width:380 height:300
    
    -- 模型详细信息区域
    groupBox grpModelInfo "模型详细信息" pos:[400,10] width:200 height:200
    dotNetControl edtModelInfo "System.Windows.Forms.TextBox" pos:[410,30] width:180 height:170
    
    -- 操作日志区域
    groupBox grpLog "操作日志" pos:[400,220] width:200 height:150
    dotNetControl edtLog "System.Windows.Forms.TextBox" pos:[410,240] width:180 height:120

    -- 初始化日志文本框
    fn initLogTextBox =
    (
        edtLog.Multiline = true
        edtLog.ReadOnly = true
        edtLog.TextAlign = edtLog.TextAlign.Center
        edtLog.BackColor = (dotNetClass "System.Drawing.Color").LightGray -- 设置背景颜色
        edtLog.BorderStyle = edtLog.BorderStyle.None -- 去掉边框
    )

    -- 初始化模型详细信息文本框
    fn initModelInfoTextBox =
    (
        edtModelInfo.Multiline = true
        edtModelInfo.ReadOnly = true
        edtModelInfo.TextAlign = edtModelInfo.TextAlign.Center
        edtModelInfo.BackColor = (dotNetClass "System.Drawing.Color").LightGray -- 设置背景颜色
        edtModelInfo.BorderStyle = edtModelInfo.BorderStyle.None -- 去掉边框
    )

    -- 按钮和进度条
    button btnCheck "检查" pos:[10,320] width:100 height:40
    button btnReplace "替换" pos:[120,320] width:100 height:40
    button btnClearLog "清除日志" pos:[400,380] width:100 height:30
    progressbar pbProgress "进度" pos:[10,370] width:380 height:20

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
        local startTime = timestamp() -- 开始时间
        missingMaps = #() -- 清空之前的结果
        local totalModels = geometry.count -- 统计整场景中的模型数量
        local totalMaps = 0
        local missingModelsCount = 0
        local missingMapsCount = 0
        local uniqueMissingMaps = #() -- 用于存储唯一的丢失贴图名称
        local uniqueMissingModels = #() -- 用于存储唯一的丢失模型名称

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
                            append missingMaps #(obj.name, subMat.name, i, getFilenameFile fileName)
                            if findItem uniqueMissingMaps (getFilenameFile fileName) == 0 then
                            (
                                append uniqueMissingMaps (getFilenameFile fileName)
                                missingMapsCount += 1
                            )
                            if findItem uniqueMissingModels obj.name == 0 then
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
                        append missingMaps #(obj.name, mat.name, 1, getFilenameFile fileName)
                        if findItem uniqueMissingMaps (getFilenameFile fileName) == 0 then
                        (
                            append uniqueMissingMaps (getFilenameFile fileName)
                            missingMapsCount += 1
                        )
                        if findItem uniqueMissingModels obj.name == 0 then
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

        local endTime = timestamp() -- 结束时间
        local elapsedTime = (endTime - startTime) / 1000.0 -- 计算耗时，单位为秒

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

        edtLog.text = logMessage + edtLog.text
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
                -- 获取模型详细信息
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

                -- 更新文本框
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
        -- 这里添加替换功能的代码
        messageBox "替换功能待实现"
    )

    -- 清除日志按钮点击事件
    on btnClearLog pressed do
    (
        edtLog.text = ""
    )

    -- 初始化
    on replaceMissingMapsRollout open do
    (
        initListView()
        initLogTextBox() -- 初始化日志文本框的对齐方式和背景颜色
        initModelInfoTextBox() -- 初始化模型详细信息文本框的对齐方式和背景颜色
    )
)

-- 显示UI
try
(
    createDialog replaceMissingMapsRollout width:610 height:420
)
catch
(
    messageBox ("创建UI时发生错误：" + (getCurrentException()))
)