-- 模型聚焦功能.ms
-- 这个脚本用于在UI中显示项目中的模型，并实现选中和聚焦功能

-- 创建UI
rollout modelFocusRollout "模型聚焦"
(
    -- 列表视图
    dotNetControl lvModels "System.Windows.Forms.ListView" pos:[10,10] width:380 height:300
    
    -- 按钮
    button btnRefresh "刷新" pos:[10,320] width:100 height:40
    button btnClose "关闭" pos:[120,320] width:100 height:40

    -- 文本框
    editText txtModelInfo "" pos:[10,370] width:380 height:60 readOnly:true

    -- 初始化列表视图
    fn initListView =
    (
        lvModels.view = lvModels.View.Details
        lvModels.GridLines = true
        lvModels.FullRowSelect = true
        lvModels.MultiSelect = false
        lvModels.Columns.Clear()
        lvModels.Columns.Add "模型名称" 350
    )

    -- 刷新模型列表
    fn refreshModelList =
    (
        lvModels.Items.Clear()
        for obj in geometry do
        (
            local item = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
            lvModels.Items.Add item
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
                txtModelInfo.text = "名称: " + selectedObj.name + "\n材质ID数量: " + materialCount as string + "\n四边面数量: " + quadFaceCount as string
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

    -- 刷新按钮点击事件
    on btnRefresh pressed do
    (
        refreshModelList()
    )

    -- 关闭按钮点击事件
    on btnClose pressed do
    (
        closeRolloutFloater modelFocusFloater
    )

    -- 初始化
    on modelFocusRollout open do
    (
        initListView()
        refreshModelList()
    )
)

-- 显示UI
try
(
    modelFocusFloater = newRolloutFloater "模型聚焦" 400 400
    addRollout modelFocusRollout modelFocusFloater
)
catch
(
    messageBox ("创建UI时发生错误：" + (getCurrentException()))
)
