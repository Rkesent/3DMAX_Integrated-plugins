-- 创建主要的rollout界面
rollout RenameToolRollout "模型命名工具" width:550 height:250
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
)

-- 创建对话框
createDialog RenameToolRollout
