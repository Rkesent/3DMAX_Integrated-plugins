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
    editText edtModelInfo "" pos:[410,30] width:180 height:170 readOnly:true
    
    -- 操作日志区域
    groupBox grpLog "操作日志" pos:[400,220] width:200 height:150
    editText edtLog "" pos:[410,240] width:180 height:120 readOnly:true
    
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

    -- 检查按钮点击事件
    on btnCheck pressed do
    (
        -- 这里添加检查功能的代码
        messageBox "检查功能待实现"
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