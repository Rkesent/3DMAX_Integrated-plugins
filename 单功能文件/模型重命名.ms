-- 创建一个基本的UI界面
rollout renameRollout "模型重命名"
(
    -- 文本框用于输入新名称前缀
    edittext prefixText "名称前缀:" text:"新名称_"
    
    -- 按钮用于执行重命名操作
    button renameButton "重命名选定模型"
    
    -- 按钮点击事件处理
    on renameButton pressed do
    (
        -- 获取用户输入的前缀
        local prefix = prefixText.text
        
        -- 遍历选定的模型
        for obj in selection do
        (
            -- 检查对象是否为几何体
            if superclassof obj == GeometryClass then
            (
                -- 重命名对象
                obj.name = prefix + obj.name
            )
        )
        
        -- 显示完成消息
        messageBox "重命名完成!"
    )
)

-- 显示UI
createDialog renameRollout
