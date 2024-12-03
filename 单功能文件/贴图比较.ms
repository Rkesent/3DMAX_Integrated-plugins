-- 清除可能存在的同名对话框
try(destroyDialog TextureCompareRollout)catch()

-- 定义全局变量存储选中的贴图路径
global texPath1 = undefined
global texPath2 = undefined

-- 比较贴图的函数
fn compareTextureMaps path1 path2 = (
    if path1 == undefined or path2 == undefined do (
        messageBox "请选择有效的贴图!" title:"错误"
        return false
    )
    
    format "正在比较:\n路径1: %\n路径2: %\n" path1 path2
    
    -- 检查文件是否存在
    if not doesFileExist path1 or not doesFileExist path2 do (
        messageBox "文件不存在!" title:"错误"
        return false
    )
    
    -- 首先比较文件路径
    if path1 == path2 do (
        return true
    )
    
    -- 比较文件大小
    local size1 = getFileSize path1
    local size2 = getFileSize path2
    
    format "文件1大小: % bytes\n文件2大小: % bytes\n" size1 size2
    
    if size1 != size2 do (
        return false
    )
    
    -- 比较文件内容
    try (
        local file1 = fopen path1 "rb"
        local file2 = fopen path2 "rb"
        
        if file1 == undefined or file2 == undefined do (
            messageBox "无法打开文件!" title:"错误"
            return false
        )
        
        local isEqual = true
        local bufferSize = 4096 -- 每次读取4KB
        
        while true do (
            local data1 = ReadByte file1 #unsigned
            local data2 = ReadByte file2 #unsigned
            
            -- 如果到达文件末尾
            if data1 == undefined and data2 == undefined do (
                exit
            )
            
            -- 如果数据不相等
            if data1 != data2 do (
                isEqual = false
                exit
            )
        )
        
        fclose file1
        fclose file2
        
        return isEqual
    )
    catch (
        if file1 != undefined do fclose file1
        if file2 != undefined do fclose file2
        messageBox ("比较过程出错: " + getCurrentException()) title:"错误"
        return false
    )
)

rollout TextureCompareRollout "贴图比较工具 v1.0" width:300 (
    group "选择贴图" (
        button btn_map1 "选择贴图 1" width:280 height:30
        label lbl_map1 "未选择贴图" width:280
        button btn_map2 "选择贴图 2" width:280 height:30
        label lbl_map2 "未选择贴图" width:280
    )
    
    group "操作" (
        button btn_compare "比较贴图" width:280 height:40
        button btn_clear "清除选择" width:280 height:30
    )
    
    -- 选择贴图1
    on btn_map1 pressed do (
        local filePath = getOpenFileName \
            caption:"选择第一个贴图" \
            types:"图片文件|*.jpg;*.jpeg;*.png;*.tga;*.tif;*.tiff;*.bmp|所有文件|*.*|"
        
        if filePath != undefined do (
            texPath1 = filePath
            lbl_map1.text = getFilenameFile filePath
            btn_map1.text = "贴图1: " + lbl_map1.text
        )
    )
    
    -- 选择贴图2
    on btn_map2 pressed do (
        local filePath = getOpenFileName \
            caption:"选择第二个贴图" \
            types:"图片文件|*.jpg;*.jpeg;*.png;*.tga;*.tif;*.tiff;*.bmp|所有文件|*.*|"
        
        if filePath != undefined do (
            texPath2 = filePath
            lbl_map2.text = getFilenameFile filePath
            btn_map2.text = "贴图2: " + lbl_map2.text
        )
    )
    
    -- 比较按钮
    on btn_compare pressed do (
        if texPath1 != undefined and texPath2 != undefined then (
            clearListener()
            format "开始比较贴图...\n"
            
            local startTime = timestamp()
            local result = compareTextureMaps texPath1 texPath2
            local endTime = timestamp()
            
            format "比较用时: % 秒\n" ((endTime - startTime) / 1000.0)
            
            if result then (
                messageBox "这两个贴图是相同的!" title:"比较结果"
            ) else (
                messageBox "这两个贴图是不同的!" title:"比较结果"
            )
        ) else (
            messageBox "请先选择两个贴图!" title:"错误"
        )
    )
    
    -- 清除按钮
    on btn_clear pressed do (
        texPath1 = undefined
        texPath2 = undefined
        btn_map1.text = "选择贴图 1"
        btn_map2.text = "选择贴图 2"
        lbl_map1.text = "未选择贴图"
        lbl_map2.text = "未选择贴图"
    )
)

-- 创建对话框
createDialog TextureCompareRollout
