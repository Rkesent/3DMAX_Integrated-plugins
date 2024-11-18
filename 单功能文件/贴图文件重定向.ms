-- 初始化计数器


-- 创建一个简单的 UI 窗口
rollout textureRedirector "贴图文件重定向" (
    local successCount = 0
    local failureCount = 0

    button btnSelectPath "选择新路径"
    editText edtNewDirectory "新路径:" text:"C:\\maps\\"
    button btnFind "查找并重定向贴图"

    on btnSelectPath pressed do (
        -- 弹出选择路径对话框
        local selectedPath = getSavePath caption:"选择新路径"
        if selectedPath != undefined do (
            edtNewDirectory.text = selectedPath
        )
    )

    on btnFind pressed do (
        -- 获取用户输入的新路径
        local newDirectory = edtNewDirectory.text

        -- 重置计数器
        successCount = 0
        failureCount = 0

        -- 遍历场景中的所有材质
        for m in scenematerials do (
            -- 遍历材质的所有贴图插槽
            for p in getpropnames m where isproperty m p and iskindof (getproperty m p) BitmapTexture do (
                local tex = getproperty m p
                -- 获取当前贴图路径
                local oldPath = tex.filename
                local fileName = getFilenameFile oldPath
                local newPath = newDirectory + "\\" + fileName + getFilenameType oldPath

                -- 检查新路径下的文件是否存在
                if doesFileExist newPath then (
                    -- 更新贴图路径
                    tex.filename = newPath
                    successCount += 1
                    format "Updated texture path: % -> %\n" oldPath newPath
                ) else (
                    failureCount += 1
                    format "Texture not found: %\n" newPath
                )
            )
        )

        -- 弹出结果
        messageBox ("替换成功: " + successCount as string + "\n未查找到: " + failureCount as string) title:"贴图路径更新结果"
    )
)

-- 显示窗口
createDialog textureRedirector
