-- 后期处理工具集
-- 这个脚本用于查找和替换3ds Max场景中丢失的漫反射贴图
-- 如出现报错不能自己修改请联系作者：ly2552674305@163.com
-- 开源地址：https://github.com/Rkesent/3DMAX_Integrated-plugins
-- 更新按钮如果不能更新脚本可在上面网址更新脚本。

-- 内存管理优化组件
-- 全局资源管理器
struct GlobalResourceManager (
    -- 私有成员
    _missingMaps = #(),
    _isProcessing = false,
    _textureRenameHistory = #(),
    _openBitmaps = #(),
    _dotNetObjects = #(),
    _stringStreams = #(),
    
    -- 获取器方法
    fn getMissingMaps = _missingMaps,
    fn getIsProcessing = _isProcessing,
    fn getTextureRenameHistory = _textureRenameHistory,
    
    -- 设置器方法
    fn setIsProcessing state = (_isProcessing = state),
    fn setMissingMaps maps = (_missingMaps = maps),
    fn setTextureRenameHistory history = (_textureRenameHistory = history),
    
    -- 位图管理
    fn registerBitmap bmap = (
        if bmap != undefined do (
            append _openBitmaps bmap
        )
    ),
    
    fn unregisterBitmap bmap = (
        if bmap != undefined do (
            local index = findItem _openBitmaps bmap
            if index > 0 do (
                deleteItem _openBitmaps index
            )
        )
    ),
    
    -- .NET对象管理
    fn registerDotNetObject obj = (
        if obj != undefined do (
            append _dotNetObjects obj
        )
    ),
    
    fn unregisterDotNetObject obj = (
        if obj != undefined do (
            local index = findItem _dotNetObjects obj
            if index > 0 do (
                deleteItem _dotNetObjects index
            )
        )
    ),
    
    -- 字符串流管理
    fn registerStringStream stream = (
        if stream != undefined do (
            append _stringStreams stream
        )
    ),
    
    -- 清理所有资源
    fn cleanup = (
        try (
            -- 清理位图
            for bmap in _openBitmaps do (
                try (close bmap) catch ()
            )
            _openBitmaps = #()
            
            -- 清理.NET对象
            for obj in _dotNetObjects do (
                try (
                    if obj != undefined do (
                        obj.Dispose()
                    )
                ) catch ()
            )
            _dotNetObjects = #()
            
            -- 清理字符串流
            for stream in _stringStreams do (
                try (
                    if stream != undefined do (
                        free stream
                    )
                ) catch ()
            )
            _stringStreams = #()
            
            -- 清理数组
            _missingMaps = #()
            _textureRenameHistory = #()
            
            -- 强制垃圾回收
            gc()
            gc light:true
            
            format "全局资源清理完成\n"
        ) catch (
            format "资源清理时出错: %\n" (getCurrentException())
        )
    ),
    
    -- 获取内存使用统计
    fn getMemoryStats = (
        local stats = #(
            #("位图数量", _openBitmaps.count),
            #(".NET对象数量", _dotNetObjects.count),
            #("字符串流数量", _stringStreams.count),
            #("丢失贴图数量", _missingMaps.count),
            #("重命名历史数量", _textureRenameHistory.count)
        )
        return stats
    )
)

-- 安全位图操作结构
struct SafeBitmapOperator (
    fn withBitmap filePath operation = (
        local bmap = undefined
        local result = undefined
        
        try (
            bmap = openBitMap filePath
            if bmap != undefined then (
                -- 注册到资源管理器
                g_resourceManager.registerBitmap bmap
                
                -- 执行操作
                result = operation bmap filePath
            ) else (
                result = #(false, "无法打开位图: " + filePath)
            )
        ) catch (
            result = #(false, "位图操作异常: " + (getCurrentException()))
        )
        
        -- 确保资源释放
        if bmap != undefined do (
            try (
                close bmap
                g_resourceManager.unregisterBitmap bmap
            ) catch ()
        )
        
        return result
    ),
    
    -- 批量位图操作
    fn withBitmaps filePaths operation = (
        local results = #()
        local openBitmaps = #()
        
        try (
            -- 打开所有位图
            for filePath in filePaths do (
                local bmap = openBitMap filePath
                if bmap != undefined then (
                    append openBitmaps bmap
                    g_resourceManager.registerBitmap bmap
                )
            )
            
            -- 执行批量操作
            if openBitmaps.count > 0 then (
                results = operation openBitmaps
            )
        ) catch (
            results = #(false, "批量位图操作异常: " + (getCurrentException()))
        )
        
        -- 清理所有位图
        for bmap in openBitmaps do (
            try (
                close bmap
                g_resourceManager.unregisterBitmap bmap
            ) catch ()
        )
        
        return results
    )
)

-- 内存监控工具
struct MemoryMonitor (
    _lastMemoryUsage = 0,
    _checkInterval = 5000, -- 5秒检查一次
    _timer = undefined,
    
    fn startMonitoring = (
        try (
            _timer = dotNetObject "System.Windows.Forms.Timer"
            _timer.Interval = _checkInterval
            
            -- 注册到资源管理器
            g_resourceManager.registerDotNetObject _timer
            
            dotNet.addEventHandler _timer "Tick" checkMemoryUsage
            _timer.Start()
            
            format "内存监控已启动\n"
        ) catch (
            format "启动内存监控失败: %\n" (getCurrentException())
        )
    ),
    
    fn stopMonitoring = (
        try (
            if _timer != undefined do (
                _timer.Stop()
                g_resourceManager.unregisterDotNetObject _timer
                _timer.Dispose()
                _timer = undefined
            )
            format "内存监控已停止\n"
        ) catch (
            format "停止内存监控失败: %\n" (getCurrentException())
        )
    ),
    
    fn checkMemoryUsage sender args = (
        try (
            -- 获取当前内存使用情况
            local currentMemory = heapSize
            local memoryDiff = currentMemory - _lastMemoryUsage
            
            -- 如果内存增长超过阈值，触发清理
            if memoryDiff > 50000000 do ( -- 50MB阈值
                format "检测到内存增长: %MB，触发清理\n" (memoryDiff / 1048576.0)
                enhancedCleanupResources()
            )
            
            _lastMemoryUsage = currentMemory
            
            -- 输出资源统计
            if g_resourceManager != undefined do (
                local stats = g_resourceManager.getMemoryStats()
                format "资源统计: "
                for stat in stats do (
                    format "%: % " stat[1] stat[2]
                )
                format "\n"
            )
        ) catch (
            format "内存检查出错: %\n" (getCurrentException())
        )
    )
)

-- 改进的资源清理函数
fn enhancedCleanupResources = (
    try (
        -- 使用资源管理器清理
        if g_resourceManager != undefined do (
            g_resourceManager.cleanup()
        )
        
        -- 清理材质库
        purgeUnusedMtlLib()
        
        -- 清理位图代理
        bitmapproxy.freeallbitmaps()
        
        -- 多次垃圾回收确保彻底清理
        for i = 1 to 3 do (
            gc()
            gc light:true
        )
        
        format "增强资源清理完成\n"
    ) catch (
        format "增强资源清理时出错: %\n" (getCurrentException())
    )
)

-- 获取详细内存使用统计
fn getDetailedMemoryStats = (
    local stats = #()
    
    try (
        format "开始收集内存使用统计数据...\n"
        
        -- 获取3ds Max堆内存信息
        local totalHeap = heapSize()
        local freeHeap = heapFree()
        local usedHeap = totalHeap - freeHeap
        
        -- 转换为MB并格式化
        local totalHeapMB = (totalHeap / 1048576.0) as string + " MB"
        local freeHeapMB = (freeHeap / 1048576.0) as string + " MB"
        local usedHeapMB = (usedHeap / 1048576.0) as string + " MB"
        local usagePercent = (100 * (usedHeap as float / totalHeap as float)) as string + "%"
        
        -- 获取系统内存信息(如果支持)
        local systemTotalMem = "未知"
        local systemFreeMem = "未知"
        local systemUsedMem = "未知"
        local systemUsagePercent = "未知"
        
        try (
            -- 尝试获取Windows内存信息
            local sysMemory = sysInfo.getSystemMemoryInfo()
            if sysMemory != undefined then (
                -- 物理内存信息(MB)
                systemTotalMem = (sysMemory.physicalMemoryTotal / 1048576.0) as string + " MB"
                systemFreeMem = (sysMemory.physicalMemoryAvailable / 1048576.0) as string + " MB"
                local sysUsed = sysMemory.physicalMemoryTotal - sysMemory.physicalMemoryAvailable
                systemUsedMem = (sysUsed / 1048576.0) as string + " MB"
                systemUsagePercent = (100 * (sysUsed as float / sysMemory.physicalMemoryTotal as float)) as string + "%"
            )
        ) catch (
            format "获取系统内存信息失败: %\n" (getCurrentException())
        )
        
        -- 获取场景统计信息
        local objectsCount = "未知"
        local materialsCount = "未知"
        local texturesCount = "未知"
        
        try (
            objectsCount = objects.count as string + " 个"
            materialsCount = sceneMaterials.count as string + " 个"
            
            -- 统计唯一的贴图文件数量
            local uniqueTexturePaths = #()
            for mat in sceneMaterials do (
                if classof mat == MultiMaterial then (
                    for i = 1 to mat.numsubs do (
                        local subMat = mat[i]
                        if subMat != undefined then (
                            local diffuseMap = case classof subMat of (
                                StandardMaterial: subMat.diffuseMap
                                VRayMtl: subMat.texmap_diffuse
                                PhysicalMaterial: subMat.base_color_map
                                default: undefined
                            )
                            
                            if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                if findItem uniqueTexturePaths diffuseMap.filename == 0 then (
                                    append uniqueTexturePaths diffuseMap.filename
                                )
                            )
                        )
                    )
                ) else (
                    local diffuseMap = case classof mat of (
                        StandardMaterial: mat.diffuseMap
                        VRayMtl: mat.texmap_diffuse
                        PhysicalMaterial: mat.base_color_map
                        default: undefined
                    )
                    
                    if diffuseMap != undefined and diffuseMap.filename != undefined then (
                        if findItem uniqueTexturePaths diffuseMap.filename == 0 then (
                            append uniqueTexturePaths diffuseMap.filename
                        )
                    )
                )
            )
            texturesCount = uniqueTexturePaths.count as string + " 个"
            uniqueTexturePaths = undefined -- 释放内存
        ) catch (
            format "获取场景统计信息失败: %\n" (getCurrentException())
        )
        
        -- 获取资源管理器统计(如果有)
        local resourceStats = #()
        try (
            if g_resourceManager != undefined then (
                resourceStats = g_resourceManager.getMemoryStats()
            )
        ) catch (
            format "获取资源管理器统计失败: %\n" (getCurrentException())
        )
        
        -- 合并所有统计
        append stats #("3ds Max内存总量", totalHeapMB)
        append stats #("3ds Max已用内存", usedHeapMB)
        append stats #("3ds Max可用内存", freeHeapMB)
        append stats #("3ds Max内存使用率", usagePercent)
        append stats #("系统内存总量", systemTotalMem)
        append stats #("系统已用内存", systemUsedMem)
        append stats #("系统可用内存", systemFreeMem)
        append stats #("系统内存使用率", systemUsagePercent)
        append stats #("场景物体数量", objectsCount)
        append stats #("材质总数", materialsCount)
        append stats #("贴图总数", texturesCount)
        
        -- 添加资源管理器统计
        for stat in resourceStats do (
            append stats stat
        )
        
        format "内存统计数据收集完成，共%项\n" stats.count
    ) catch (
        format "获取内存统计时出错: %\n" (getCurrentException())
        -- 确保至少返回一些基本数据
        try (
            append stats #("3ds Max内存总量", (heapSize() / 1048576.0) as string + " MB")
            append stats #("3ds Max可用内存", (heapFree() / 1048576.0) as string + " MB") 
        ) catch (
            append stats #("状态", "内存统计获取失败")
        )
    )
    
    return stats
)

-- 优化的位图尺寸检查函数
fn optimizedCheckTextureSize filePath = (
    return g_bitmapOperator.withBitmap filePath (
        fn checkSize bmap filePath = (
            try (
                local w = bmap.width as integer
                local h = bmap.height as integer
                
                if w <= 0 or h <= 0 then (
                    return #(false, "无效尺寸")
                )
                
                -- 检查是否为2的幂次方
                local isPowerW = isPowerOfTwo w
                local isPowerH = isPowerOfTwo h
                
                if not isPowerW or not isPowerH then (
                    return #(false, w as string + "x" + h as string)
                )
                
                return #(true, w as string + "x" + h as string)
            ) catch (
                return #(false, "检查失败: " + (getCurrentException()))
            )
        )
    )
)

-- 创建全局实例
global g_resourceManager = GlobalResourceManager()
global g_bitmapOperator = SafeBitmapOperator()
global g_memoryMonitor = MemoryMonitor()

-- 基础函数定义
-- 确保formatNumberWithLeadingZeros是全局函数
global formatNumberWithLeadingZeros
fn formatNumberWithLeadingZeros num width = (
    try (
        -- 确保输入值有效
        if num == undefined do num = 1
        if width == undefined do width = 3
        
        -- 转换为字符串并填充
        local numStr = num as string
        while numStr.count < width do (
            numStr = "0" + numStr
        )
        return numStr
    ) catch (
        -- 发生错误时返回默认值
        return "001"
    )
)

fn isPowerOfTwo n = (
    try (
        if n == undefined or n <= 0 then return false
        local i = 1
        while i <= n do (
            if i == n then return true
            i *= 2
            if i > n then return false -- 添加这个检查以避免无限循环
        )
        return false
    ) catch (
        return false
    )
)

fn checkTextureSize bmap = (
    -- 如果直接传入位图对象
    if bmap != undefined then (
        try (
            -- 首先检查输入参数是否有效
            if bmap == undefined then return #(false, "无效贴图")
            
            -- 确保获取到有效的宽高值
            local w = undefined
            local h = undefined
            
            try (
                w = bmap.width as integer
                h = bmap.height as integer
            ) catch (
                return #(false, "无法获取贴图尺寸")
            )
            
            -- 检查是否获取到有效值
            if w == undefined or h == undefined or w <= 0 or h <= 0 then (
                return #(false, "无效尺寸")
            )
            
            -- 检查是否为2的幂次方
            local isPowerW = isPowerOfTwo w
            local isPowerH = isPowerOfTwo h
            
            if not isPowerW or not isPowerH then (
                return #(false, w as string + "x" + h as string)
            )
            
            return #(true, w as string + "x" + h as string)
        ) catch (
            return #(false, "检查失败: " + (getCurrentException()))
        )
    ) else (
        -- 如果传入的是文件路径，使用安全位图操作器
        return optimizedCheckTextureSize bmap
    )
)

-- 全局变量声明
-- 全局变量现在由资源管理器管理
-- global missingMaps = #()
-- global isProcessing = false

-- 内存统计更新计时器
global updateMemoryStatsTimer = undefined

-- 启动内存统计更新计时器
fn startMemoryStatsTimer interval:5000 = (
    try (
        format "开始启动内存统计更新计时器...\n"
        
        -- 如果已经有计时器在运行，先停止
        if updateMemoryStatsTimer != undefined do (
            try (
                updateMemoryStatsTimer.Stop()
                g_resourceManager.unregisterDotNetObject updateMemoryStatsTimer
                updateMemoryStatsTimer.Dispose()
            ) catch (
                format "停止旧计时器出错: %\n" (getCurrentException())
            )
            updateMemoryStatsTimer = undefined
        )
        
        -- 创建新的计时器
        updateMemoryStatsTimer = dotNetObject "System.Windows.Forms.Timer"
        updateMemoryStatsTimer.Interval = interval
        
        -- 注册到资源管理器
        g_resourceManager.registerDotNetObject updateMemoryStatsTimer
        
        -- 定义更新函数
        fn memoryStatsTimerTick sender args = (
            try (
                -- 直接在计时器中添加数据，避免依赖其他函数
                if lvMemoryStats != undefined and lvMemoryStats.visible then (
                    try (
                        -- 更新基本内存数据
                        local totalHeap = heapSize()
                        local freeHeap = heapFree()
                        local usedHeap = totalHeap - freeHeap
                        local totalHeapMB = (totalHeap / 1048576.0) as string + " MB"
                        local freeHeapMB = (freeHeap / 1048576.0) as string + " MB"
                        
                        -- 检查是否已有这些项
                        local foundItems = #()
                        for i = 0 to lvMemoryStats.Items.Count - 1 do (
                            local itemName = lvMemoryStats.Items.Item[i].Text
                            append foundItems itemName
                            
                            -- 更新现有数据
                            if itemName == "3ds Max内存总量" then 
                                lvMemoryStats.Items.Item[i].SubItems.Item[1].Text = totalHeapMB
                            else if itemName == "3ds Max可用内存" then
                                lvMemoryStats.Items.Item[i].SubItems.Item[1].Text = freeHeapMB
                        )
                        
                        -- 如果没有找到这些项，尝试调用完整更新
                        if foundItems.count == 0 then (
                            updateMemoryStats()
                        )
                    ) catch (
                        format "计时器中更新内存数据失败: %\n" (getCurrentException())
                    )
                )
            ) catch (
                format "内存统计更新时出错: %\n" (getCurrentException())
            )
        )
        
        -- 添加事件处理
        dotNet.addEventHandler updateMemoryStatsTimer "Tick" memoryStatsTimerTick
        updateMemoryStatsTimer.Start()
        
        format "内存统计更新计时器已启动，间隔: %毫秒\n" interval
        return true
    ) catch (
        format "启动内存统计更新计时器失败: %\n" (getCurrentException())
        return false
    )
)

-- 停止内存统计更新计时器
fn stopMemoryStatsTimer = (
    try (
        if updateMemoryStatsTimer != undefined do (
            updateMemoryStatsTimer.Stop()
            g_resourceManager.unregisterDotNetObject updateMemoryStatsTimer
            updateMemoryStatsTimer.Dispose()
            updateMemoryStatsTimer = undefined
            format "内存统计更新计时器已停止\n"
        )
        return true
    ) catch (
        format "停止内存统计更新计时器失败: %\n" (getCurrentException())
        return false
    )
)

-- 资源管理相关函数
fn cleanupDotNetObject obj = (
    try (
        if obj != undefined do (
            g_resourceManager.unregisterDotNetObject obj
            obj.Dispose()
            obj = undefined
        )
    ) catch()
)

fn cleanupResources = (
    -- 使用增强的资源清理函数
    enhancedCleanupResources()
)

fn cleanupListView lv = (
    try (
        if lv != undefined do (
            -- 清空列表项
            lv.Items.Clear()
            -- 清空列
            lv.Columns.Clear()
            -- 从资源管理器注销并释放资源
            g_resourceManager.unregisterDotNetObject lv
            cleanupDotNetObject lv
        )
    ) catch (
        format "清理ListView时出错: %\n" (getCurrentException())
    )
)

fn cleanupBitmap bmap = (
    try (
        if bmap != undefined do (
            -- 从资源管理器中注销位图
            g_resourceManager.unregisterBitmap bmap
            -- 关闭并清理位图
            close bmap
            bmap = undefined
        )
    ) catch (
        format "清理位图时出错: %\n" (getCurrentException())
    )
)

fn periodicCleanup = (
    try (
        -- 清理未使用的材质
        purgeUnusedMtlLib()
        
        -- 清理未使用的位图
        bitmapproxy.freeallbitmaps()
        
        -- 强制垃圾回收
        gc()
        gc light:true
    ) catch (
        format "定期清理时出错: %\n" (getCurrentException())
    )
)

-- 新增：输入验证函数
fn trimAndValidateInput txt = (
    if txt == undefined then return false
    local trimmed = trimRight (trimLeft txt)
    trimmed != ""
)

-- 新增：序号生成函数
fn generateSequenceNumber num width = (
    try (
        -- 确保是有效数字
        local validNum = if num == undefined then 1 else num as integer
        -- 转换为字符串并填充
        local numStr = validNum as string
        while numStr.count < width do (
            numStr = "0" + numStr
        )
        return numStr
    ) catch (
        format "序号生成错误: %\n" (getCurrentException())
        return "001" -- 返回默认值
    )
)

-- 新增：对象重命名函数
global renameObject
fn renameObject obj newName = (
    try (
        if obj != undefined and isValidNode obj then (
            local oldName = obj.name
            obj.name = newName
            -- 验证重命名是否成功
            if obj.name != newName then (
                format "重命名失败: % -> %\n" oldName newName
                return false
            )
            return true
        )
        return false
    ) catch (
        format "重命名出错: %\n" (getCurrentException())
        return false
    )
)

-- 新增：批量重命名函数
global renameModels
fn renameModels baseCode cityName projName abbrName startNum fillCount objsToProcess = (
    local errorLog = stringStream ""
    local processedCount = 0
    local errorCount = 0
    local duplicateNames = #()
    
    try (
        -- 验证输入参数 - 如果部分参数为空也允许继续
        if startNum == undefined or fillCount == undefined then (
            format "序号参数无效\n" to:errorLog
            return #(0, 1, errorLog as string)
        )
        
        -- 验证对象数组
        if objsToProcess == undefined or objsToProcess.count == 0 then (
            format "没有要处理的对象\n" to:errorLog
            return #(0, 1, errorLog as string)
        )
        
        -- 当前序号
        local currentNum = startNum
        
        -- 预先检查名称冲突
        local proposedNames = #()
        for obj in objsToProcess do (
            if obj != undefined and isValidNode obj then (
                local numStr = formatNumberWithLeadingZeros currentNum fillCount
                -- 使用数组收集非空部分，然后用下划线连接
                local nameParts = #()
                if baseCode != "" then append nameParts baseCode
                if cityName != "" then append nameParts cityName
                if projName != "" then append nameParts projName
                if abbrName != "" then append nameParts abbrName
                append nameParts numStr
                
                -- 用下划线连接所有部分
                local newName = nameParts[1]
                for i = 2 to nameParts.count do (
                    newName += "_" + nameParts[i]
                )
                
                -- 检查名称是否已存在
                if findItem proposedNames newName > 0 then (
                    append duplicateNames newName
                )
                append proposedNames newName
                currentNum += 1
            )
        )
        
        -- 如果存在重复名称，记录错误并返回
        if duplicateNames.count > 0 then (
            format "检测到重复名称:\n" to:errorLog
            for name in duplicateNames do format "  %\n" name to:errorLog
            return #(0, duplicateNames.count, errorLog as string)
        )
        
        -- 重置序号进行实际重命名
        currentNum = startNum
        
        -- 处理每个对象
        for obj in objsToProcess do (
            try (
                if obj != undefined and isValidNode obj then (
                    -- 生成新名称
                    local numStr = formatNumberWithLeadingZeros currentNum fillCount
                    -- 使用数组收集非空部分，然后用下划线连接
                    local nameParts = #()
                    if baseCode != "" then append nameParts baseCode
                    if cityName != "" then append nameParts cityName
                    if projName != "" then append nameParts projName
                    if abbrName != "" then append nameParts abbrName
                    append nameParts numStr
                    
                    -- 用下划线连接所有部分
                    local newName = nameParts[1]
                    for i = 2 to nameParts.count do (
                        newName += "_" + nameParts[i]
                    )
                    
                    -- 保存旧名称用于错误报告
                    local oldName = obj.name
                    
                    -- 尝试重命名
                    if (renameObject obj newName) then (
                        processedCount += 1
                        currentNum += 1
                    ) else (
                        errorCount += 1
                        format "重命名失败: % -> %\n" oldName newName to:errorLog
                    )
                ) else (
                    errorCount += 1
                    format "无效对象: %\n" (if obj != undefined then obj.name else "undefined") to:errorLog
                )
            ) catch (
                errorCount += 1
                format "处理对象时出错: % (对象: %)\n" (getCurrentException()) (if obj != undefined then obj.name else "undefined") to:errorLog
            )
        )
        
        -- 返回结果
        local result = #(processedCount, errorCount, errorLog as string)
        
        -- 清理资源
        if errorLog != undefined do (
            try(free errorLog)catch()
            errorLog = undefined
        )
        gc light:true
        
        return result
    ) catch (
        -- 处理主要错误
        format "重命名过程出错: %\n" (getCurrentException()) to:errorLog
        
        -- 清理资源
        if errorLog != undefined do (
            try(free errorLog)catch()
            errorLog = undefined
        )
        gc light:true
        
        return #(0, 1, "重命名过程发生严重错误")
    )
)

-- 添加必要的辅助函数
-- 获取材质的贴图名称
fn _getMapName _material = (
    try (
        _mapName = ""
        -- 检查材质是否为空
        if _material == undefined then return ""
        
        -- 检查diffuseMap
        if _material.diffuseMap != undefined then (
            if _material.diffuseMap.fileName != undefined then (
                _fileName = _material.diffuseMap.fileName
                _arr = filterString _fileName "\\"
                _mapName = (FilterString _arr[_arr.count] ".")[1]
                return _mapName
            )
        )
        
        -- 检查specularMap
        if _material.specularMap != undefined then (
            if _material.specularMap.fileName != undefined then (
                _fileName = _material.specularMap.fileName
                _arr = filterString _fileName "\\"
                _mapName = (FilterString _arr[_arr.count] ".")[1]
            )
        )
        return _mapName
    )
    catch (
        -- 发生错误时返回空字符串
        return ""
    )
)

-- 设置材质的名称和贴图名称
fn _setMaterialName _material = (
    try (
        -- 检查材质是否为空
        if _material == undefined then return false
        
        if(classof _material == MultiMaterial) then (
            matList = _material.MaterialList
            if matList != undefined and matList.count > 0 then (
                for m in matList where m != undefined do (
                    _setMaterialName m
                )
                _mapName = _getMapName matList[1]
                if _mapName != "" then (
                    _mapName = substring _mapName 2 -1
                    _material.name = "MATM" + _mapName
                )
            )
        )
        else (
            _mapName = _getMapName _material
            if(_mapName != "") then (
                _material.name = "MA" + _mapName
                if(_material.diffuseMap != undefined) then (
                    try(_material.diffuseMap.name = _mapName) catch()
                )
                if(_material.specularMap != undefined) then (
                    try(_material.specularMap.name = _mapName) catch()
                )
            )
            else (
                _material.name = "MAT"
            )
        )
        return true
    )
    catch (
        format "Error in _setMaterialName: %\n" (getCurrentException())
        return false
    )
)

-- 根据材质id获取面
fn _getFaceIDByMaterialID g id = (
    faceIDArr = #()
    allFace = polyOp.getNumFaces g
    for i = 1 to allFace do (
        faceMatID = polyOp.getFaceMatID g i
        if(faceMatID == id) then (
            append faceIDArr i
        )
    )
    return faceIDArr
)

-- 根据贴图名称查询材质数组中是否已经包含该贴图
fn getIndexByMapName matArr mapName = (
    index = 0
    for m = 1 to matArr.count do (
        _mapName = _getMapName matArr[m]
        if(mapName == _mapName) then (
            index = m
            exit
        )
    )
    return index
)

-- 根据diffuse颜色查询索引
fn getIndexByDiffuse matArr _color = (
    index = 0
    for m = 1 to matArr.count do (
        local color2 = case classof matArr[m] of (
            StandardMaterial: matArr[m].diffuse
            VRayMtl: matArr[m].diffuse
            PhysicalMaterial: matArr[m].base_color
            default: color 128 128 128 -- 默认灰色
        )
        if(_color == color2) then (
            index = m
            exit
        )
    )
    return index
)

-- 根据名称查询材质数组中是否已经包含该贴图的部分名称
fn includeByName matArr _name = (
    index = 0
    for m = 1 to matArr.count do (
        _mapName = _getMapName matArr[m]
        flog = findString _mapName _name
        if(flog != undefined) then (
            index = m
            exit
        )
    )
    return index
)

-- 将多维数组展开成一维
fn unfoldArr oldArr = (
    newArr = #()
    for i in oldArr do (
        if(classof i == Array) then (
            arr = unfoldArr i
            for j in arr do (
                append newArr j
            )
        )
        else (
            append newArr i
        )
    )
    return newArr
)

-- 优化材质
fn optimaizeMat geo = (
    mat = geo.material
    matIdList = mat.materialIDList
    matList = mat.materialList
    materialArr = #()
    faceArr = #()
    
    for index = 1 to matIdList.count do (
        matId = matIdList[index]
        mat = matList[index]
        face = _getFaceIDByMaterialID geo matId
        
        if(face.count == 0) then continue
        
        _mapName = _getMapName mat
        index = getIndexByMapName materialArr _mapName
        
        if(index == 0) then (
            index_gaojing = includeByName materialArr "高精贴片"
            isInclude = findString (_getMapName mat) "高精贴片"
            
            if(index_gaojing == 0 and isInclude != undefined) then (
                insertItem mat materialArr 1
                insertItem face faceArr 1
            )
            else (
                append materialArr mat
                append faceArr face
            )
        )
        else (
            if(_mapName == "") then (
                local color1 = case classof mat of (
                    StandardMaterial: mat.diffuse
                    VRayMtl: mat.diffuse
                    PhysicalMaterial: mat.base_color
                    default: color 128 128 128
                )
                __index = getIndexByDiffuse materialArr color1
                if(__index != 0) then (
                    append faceArr[__index] face
                )
                else (
                    append materialArr mat
                    append faceArr face
                )
            )
            else (
                append faceArr[index] face
            )
        )
    )
    
    -- 重新设置新的材质
    geo.material = Multimaterial numsubs:materialArr.count
    for index = 1 to faceArr.count do (
        faceArr[index] = unfoldArr faceArr[index]
        geo.material[index] = materialArr[index]
        polyOp.setFaceMatID geo faceArr[index] index
    )
)

-- 显示材质
fn displayMat = (
    local matArr = undefined
    
    try (
        matArr = #()
        -- 更新材质编辑器
        for me = 1 to meditMaterials.count do (
            meditMaterials[me] = Standardmaterial()
        )
        
        -- 收集材质
        for g in selection do (
            if((findItem matArr g.material) == 0) then (
                append matArr g.material
            )
        )
        
        -- 更新传统材质编辑器
        for m = 1 to matArr.count do (
            meditMaterials[m] = matArr[m]
        )
        
        -- 更新 Slate 材质编辑器
        if (sme.isOpen()) then (
            try(
                -- 清除现有视图
                sme.views[sme.activeView].ClearAll()
                
                -- 添加材质到 Slate 编辑器
                local posX = 100
                local posY = 100
                for mat in matArr do (
                    try(
                        
                        local newNode = sme.CreateMaterialNode mat [posX, posY]
                        posY += 150 -- 调整下一个材质的位置
                    )catch()
                )
                
                -- 重新布局视图
                sme.views[sme.activeView].ZoomToSelected()
                sme.views[sme.activeView].Redraw()
            )catch(
                format "Slate编辑器操作失败: %\n" (getCurrentException())
            )
        )
        
        -- 清理资源
        if matArr != undefined do (
            matArr = undefined
            gc light:true
        )
    ) catch (
        format "更新材质编辑器时出错: %\n" (getCurrentException())
        -- 
        if matArr != undefined do matArr = undefined
        gc light:true
    )
)

-- 自定义函数：查数组中是否存在某个元素
fn arrayContains arr item =
(
    local found = false
    for i in arr where i == item do found = true
    found
)


fn disableButton btn = (
    if btn != undefined do (
        btn.enabled = false
    )
)

fn enableButton btn = (
    if btn != undefined do (
        btn.enabled = true
    )
)

-- 新增：ListView操作辅助函数
fn initializeListView lv = (
    try (
        if lv != undefined then (
            lv.View = lv.View.Details
            lv.FullRowSelect = true
            lv.GridLines = true
            lv.MultiSelect = true
            
            -- 清除现有列
            lv.Columns.Clear()
            
            -- 添加列
            lv.Columns.Add "模型名称" 100
            lv.Columns.Add "材质" 100
            lv.Columns.Add "ID" 50
            lv.Columns.Add "丢失贴图名称" 120
            lv.Columns.Add "错误信息" 100
            
            return true
        )
        return false
    ) catch (
        format "初始化ListView失败: %\n" (getCurrentException())
        return false
    )
)

fn clearListView lv = (
    try (
        if lv != undefined and lv.Items != undefined then (
            lv.Items.Clear()
            lv.BeginUpdate()
            return true
        )
        return false
    ) catch (
        format "清理ListView失败: %\n" (getCurrentException())
        return false
    )
)

fn addListViewItem lv item = (
    try (
        if lv != undefined and lv.Items != undefined then (
            lv.Items.Add item
            return true
        )
        return false
    ) catch (
        format "添加ListView项失败: %\n" (getCurrentException())
        return false
    )
)

fn endListViewUpdate lv = (
    try (
        if lv != undefined then (
            lv.EndUpdate()
            return true
        )
        return false
    ) catch (
        format "结束ListView更新失败: %\n" (getCurrentException())
        return false
    )
)

-- 贴图重命名历史管理
global textureRenameHistory = #()

fn loadTextureRenameHistory = (
    textureRenameHistory = #()
    local filePath = (getDir #temp) + "\\TextureRenameHistory.dat"
    if doesFileExist filePath then (
        local f = openFile filePath
        if f != undefined then (
            while not eof f do (
                local line = readLine f
                if line != undefined and line[1] != "#" then (
                    local parts = filterString line "\t"
                    if parts.count >= 3 do (
                        -- 改进的日期处理
                        local timestamp = try(parts[1] as integer)catch(parts[1])
                        append textureRenameHistory #(timestamp, parts[2], parts[3])
                    )
                )
            )
            close f
        )
    )
)

fn saveTextureRenameHistory = (
    local filePath = (getDir #temp) + "\\TextureRenameHistory.dat"
    local f = createFile filePath
    
    if f != undefined then (
        format "# 贴图重命名历史记录文件\n" to:f
        for rec in textureRenameHistory do (
            format "%\t%\t%\n" rec[1] rec[2] rec[3] to:f
        )
        close f
    )
)

-- 定义注册贴图重命名记录的全局函数
global registerTextureRename
fn registerTextureRename oldPath newPath = (
    -- 记录重命名历史
    try (
        -- 获取当前时间戳（确保是整数类型）
        local currentTime = timeStamp() as integer
        
        -- 添加到历史记录中，包含时间戳
        local record = #(
            currentTime, -- 添加时间戳，确保是整数
            oldPath,     -- 原文件路径
            newPath      -- 新文件路径
        )
        
        -- 加载现有历史
        loadTextureRenameHistory()
        
        -- 添加新记录
        append textureRenameHistory record
        
        -- 保存历史记录
        saveTextureRenameHistory()
        
        format "已记录贴图重命名: % -> %\n" oldPath newPath
        return true
    ) catch (
        format "记录贴图重命名历史出错: %\n" (getCurrentException())
        return false
    )
)

-- 定义贴图重命名撤回界面（移到全局范围）
-- 这是注释，表示这个rollout已经在文件前面定义过，不需要重复定义
-- 如需使用贴图重命名撤回功能，请参考前面的textureRollbackRollout定义

-- 这里是文件的其他内容
-- ... existing code ...

-- 创建UI
rollout replaceMissingMapsRollout "后处理工具集合-v1.3.4" width:640 height:420
(
    -- 主列表视图
    dotNetControl lvModels "System.Windows.Forms.ListView" pos:[10,10] width:400 height:300
    
    -- 模型详细信息区域
    groupBox grpModelInfo "模型详细信息" pos:[420,10] width:200 height:150
    dotNetControl edtModelInfo "System.Windows.Forms.TextBox" pos:[430,30] width:180 height:120
    
    -- 操作日志区域
    groupBox grpLog "操作日志" pos:[420,170] width:200 height:140
    dotNetControl edtLog "System.Windows.Forms.RichTextBox" pos:[430,190] width:180 height:110

    -- 右侧内存监控伸缩面板
    groupBox grpMemoryPanel "内存统计" pos:[640,10] width:250 height:380 visible:false
    dotNetControl lvMemoryStats "System.Windows.Forms.ListView" pos:[650,30] width:230 height:350 visible:false

    -- 新增折叠区域按钮
    button btnCollapsible "高级选项 ▼" pos:[400,380] width:100 height:30 tooltip:"点击展开或折叠高级选项区域（此功能暂未完善）"
    
    -- 可折叠区域
    groupBox grpCollapsible "高级选项" pos:[10,430] width:610 height:100 visible:false
    -- 在可折叠区域中添加一些控件
    button btnAdvanced1 "贴图回退" pos:[20,450] width:100 height:30 visible:false tooltip:"查看贴图重命名历史记录，可以撤销重命名操作"
    button btnCheckUpdate "检查更新" pos:[20,490] width:100 height:30 visible:false tooltip:"检查插件的最新版本"
    checkbox chkEnableMemoryMonitor "内存监控" pos:[140,450] width:90 height:30 checked:false visible:false tooltip:"勾选此项启用内存监控，自动释放未使用的资源"
    
    -- ID限制下拉框和标签
    label lblIDLimit "ID限制:" pos:[335,370] width:50 height:20 tooltip:"设置材质ID的最大数量限制"
    dotNetControl cmbIDLimit "System.Windows.Forms.ComboBox" pos:[330,390] width:60 height:21
    
    -- 添加贴图大小检测单选框
    checkbox chkMapSizeCheck "贴图大小检测" pos:[335,320] width:90 height:20 checked:false tooltip:"勾选此项启用对贴图尺寸的检测，查找非2次幂尺寸的贴图"

    -- 添加修复贴图尺寸按钮
    button btnFixTextures "修复贴图尺寸" pos:[335,340] width:100 height:20 tooltip:"尝试修复非2次幂尺寸的贴图"
    
    -- 添加内存监控按钮
    -- 内存监控单选框已移至高级选项区域
    
    -- 按钮
    button btnCheck "检查" pos:[10,320] width:100 height:40 tooltip:"检查场景中丢失的贴图和非2次幂尺寸的贴图"
    button btnReplace "替换" pos:[120,320] width:100 height:40 tooltip:"替换选中项或所有丢失的贴图"
    button btnChangePath "更换贴图路径" pos:[230,320] width:100 height:40 tooltip:"更新贴图路径，左键点击更新丢失贴图，右键点击更新所有贴图"
    button btnClearLog "清除日志" pos:[470,320] width:100 height:40 tooltip:"清空操作日志"
    
    -- 新增按钮
    button btnConvertToStandard "转化为标准材质" pos:[10,370] width:100 height:20 tooltip:"将场景中的材质转换为标准材质"
    button btnConvertToVR "转化VR材质" pos:[10,390] width:100 height:20 tooltip:"将场景中的材质转换为VRay材质"
    button btnRename "重命名" pos:[120,370] width:100 height:40 tooltip:"打开重命名工具，可对模型和贴图进行批量重命名"
    button btnCheckModelID "模型ID数检查" pos:[230,370] width:100 height:40 tooltip:"检查模型的材质ID数量是否超过限制"
    -- button btn_namemat "贴图命名材质" width:100 height:40 pos:[340,320]

    -- 添加函数声明
    fn insertLog message clearPrevious:false =
    (
        if edtLog != undefined do
        (
            if clearPrevious then
                edtLog.Clear()
                
            edtLog.Select 0 0
            edtLog.SelectedText = message + "\r\n" + edtLog.Text
        )
    )
    
    -- 折叠区域相关变量和函数
    local isCollapsibleVisible = false
    local dialogHeight = 420 -- 默认高度
    local expandedHeight = 550 -- 展开后的高度
    
    -- 展开或折叠区域的函数
    fn toggleCollapsibleArea = (
        try (
            isCollapsibleVisible = not isCollapsibleVisible
            
            -- 更新按钮文本
            if btnCollapsible != undefined then
                btnCollapsible.text = if isCollapsibleVisible then "高级选项 ▲" else "高级选项 ▼"
            
            -- 更新控件可见性，先检查控件是否存在
            if grpCollapsible != undefined then
                grpCollapsible.visible = isCollapsibleVisible
                
            if btnAdvanced1 != undefined then
                btnAdvanced1.visible = isCollapsibleVisible
                
            if btnCheckUpdate != undefined then
                btnCheckUpdate.visible = isCollapsibleVisible
                
            if chkEnableMemoryMonitor != undefined then
                chkEnableMemoryMonitor.visible = isCollapsibleVisible
            
            -- 如果展开了折叠区域，检查内存监控复选框状态
            if isCollapsibleVisible and chkEnableMemoryMonitor != undefined and chkEnableMemoryMonitor.checked then (
                -- 显示内存统计面板
                if grpMemoryPanel != undefined then grpMemoryPanel.visible = true
                if lvMemoryStats != undefined then (
                    lvMemoryStats.visible = true
                    -- 如果表格未初始化，则初始化
                    if lvMemoryStats.Columns.Count == 0 then (
                        initMemoryStatsListView()
                        updateMemoryStats()
                    )
                )
                -- 调整窗口宽度以适应内存统计面板
                try(replaceMissingMapsRollout.width = 900)catch()
            )
            
            -- 调整对话框高度
            local newHeight = if isCollapsibleVisible then expandedHeight else dialogHeight
            try(
                replaceMissingMapsRollout.height = newHeight
            )catch()
        ) catch (
            messageBox ("切换折叠区域时出错：" + (getCurrentException())) title:"错误"
        )
    )
    
    -- 折叠区域按钮点击事件
    on btnCollapsible pressed do (
        toggleCollapsibleArea()
    )
    
    -- 贴图名称历史记录按钮事件
    on btnAdvanced1 pressed do (
        try (
            -- 使用已定义的全局rollout而不是创建临时rollout
            if textureRollbackRollout != undefined then
                createDialog textureRollbackRollout modal:false
            else
                messageBox "贴图重命名撤回界面未定义，请确保全局textureRollbackRollout已正确定义。" title:"错误"
        ) catch (
            messageBox ("显示贴图撤回界面时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    -- 初始化函数
    fn initIDLimitComboBox = (
        try (
            if cmbIDLimit != undefined then (
                cmbIDLimit.Items.Clear()
                local idLimits = #(4, 8, 12, 20)
                for limit in idLimits do (
                    cmbIDLimit.Items.Add (limit as string)
                )
                cmbIDLimit.SelectedIndex = 2  -- 默认选择12
                cmbIDLimit.DropDownStyle = cmbIDLimit.DropDownStyle.DropDownList
                cmbIDLimit.BackColor = (dotNetClass "System.Drawing.Color").White
                cmbIDLimit.ForeColor = (dotNetClass "System.Drawing.Color").Black
                cmbIDLimit.Font = dotNetObject "System.Drawing.Font" "Arial" 9
                return true
            )
            return false
        ) catch (
            format "初始化ID限制下拉框时出错: %\n" (getCurrentException())
            return false
        )
    )

    -- 初始化日志文本框
    fn initLogTextBox = (
        edtLog.Multiline = true
        edtLog.ReadOnly = true
        edtLog.BackColor = (dotNetClass "System.Drawing.Color").LightGray
        edtLog.Font = dotNetObject "System.Drawing.Font" "Arial" 9
        edtLog.WordWrap = true
        edtLog.ScrollBars = edtLog.ScrollBars.Vertical
    )

    -- 初始化模型详细信息文本框
    fn initModelInfoTextBox = (
        edtModelInfo.Multiline = true
        edtModelInfo.ReadOnly = true
        edtModelInfo.TextAlign = edtModelInfo.TextAlign.Left
        edtModelInfo.BackColor = (dotNetClass "System.Drawing.Color").LightGray
        edtModelInfo.BorderStyle = edtModelInfo.BorderStyle.None
    )

    -- 初始化列表视图
    fn initListView = (
        lvModels.view = lvModels.View.Details
        lvModels.GridLines = true
        lvModels.FullRowSelect = true
        lvModels.MultiSelect = true
        lvModels.Columns.Clear()
        
        -- 重新设置列宽和位置
        local col1 = lvModels.Columns.Add "模型名称" 100
        local col2 = lvModels.Columns.Add "材质" 100
        local col3 = lvModels.Columns.Add "ID" 50
        local col4 = lvModels.Columns.Add "丢失贴图名称" 120
        local col5 = lvModels.Columns.Add "错误信息" 100
        
        -- 设置列总宽度以避免出空列
        lvModels.width = 400  -- 调整总宽度为所有列宽之和
    )
    
    -- 初始化内存统计表格
    fn initMemoryStatsListView = (
        try (
            format "开始初始化内存统计表格...\n"
            
            if lvMemoryStats != undefined then (
                -- 基本设置
                lvMemoryStats.View = lvMemoryStats.View.Details
                lvMemoryStats.GridLines = true
                lvMemoryStats.FullRowSelect = true
                lvMemoryStats.MultiSelect = false
                lvMemoryStats.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").Nonclickable
                
                -- 清除现有列并添加新列
                lvMemoryStats.Columns.Clear()
                local col1 = lvMemoryStats.Columns.Add "统计项目" 130
                local col2 = lvMemoryStats.Columns.Add "数值" 90
                
                -- 设置样式
                lvMemoryStats.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 240 240 240
                lvMemoryStats.ForeColor = (dotNetClass "System.Drawing.Color").Black
                lvMemoryStats.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").Fixed3D
                
                -- 设置字体
                try(
                    local newFont = dotNetObject "System.Drawing.Font" "Arial" 9
                    lvMemoryStats.Font = newFont
                    g_resourceManager.registerDotNetObject newFont
                )catch()
                
                -- 添加初始测试项
                try(
                    local item = dotNetObject "System.Windows.Forms.ListViewItem" "初始化测试"
                    item.SubItems.Add "成功"
                    item.ForeColor = (dotNetClass "System.Drawing.Color").Green
                    lvMemoryStats.Items.Add item
                )catch()
                
                -- 注册到资源管理器
                g_resourceManager.registerDotNetObject lvMemoryStats
                
                format "内存统计表格初始化成功\n"
                return true
            ) else (
                format "内存统计表格控件未找到\n"
                return false
            )
        ) catch (
            format "初始化内存统计表格时出错: %\n" (getCurrentException())
            return false
        )
    )
    
    -- 更新内存统计数据
    fn updateMemoryStats = (
        try (
            if lvMemoryStats != undefined then (
                -- 清空表格
                lvMemoryStats.Items.Clear()
                lvMemoryStats.BeginUpdate()
                
                -- 获取统计数据
                local stats = getDetailedMemoryStats()
                
                -- 记录到日志以便调试
                format "内存统计数据更新，共%项\n" stats.count
                
                -- 如果没有数据，添加一些默认项
                if stats.count == 0 do (
                    append stats #("3ds Max内存总量", (heapSize() / 1048576.0) as string + " MB")
                    append stats #("3ds Max可用内存", (heapFree() / 1048576.0) as string + " MB")
                    format "添加默认内存统计项\n"
                )
                
                -- 添加到表格
                for stat in stats do (
                    try (
                        -- 确保数据有效
                        local statName = if stat[1] != undefined then stat[1] as string else "未知项"
                        local statValue = if stat[2] != undefined then stat[2] as string else "未知值"
                        
                        local item = dotNetObject "System.Windows.Forms.ListViewItem" statName
                        item.SubItems.Add statValue
                        
                        -- 设置颜色样式(可选)
                        if matchPattern statName pattern:"*使用率*" then (
                            local usageValue = substituteString statValue "%" ""
                            try (
                                local usage = usageValue as float
                                if usage > 90.0 then
                                    item.ForeColor = (dotNetClass "System.Drawing.Color").Red
                                else if usage > 70.0 then
                                    item.ForeColor = (dotNetClass "System.Drawing.Color").Orange
                                else
                                    item.ForeColor = (dotNetClass "System.Drawing.Color").Green
                            ) catch()
                        )
                        
                        lvMemoryStats.Items.Add item
                    ) catch (
                        format "添加内存统计项时出错: %\n" (getCurrentException())
                    )
                )
                
                lvMemoryStats.EndUpdate()
                format "内存统计表格更新完成\n"
                return true
            ) else (
                format "内存统计表格控件未找到\n"
            )
            return false
        ) catch (
            format "更新内存统计表格时出错: %\n" (getCurrentException())
            return false
        )
    )

    -- 检查缺少的文件
    fn checkMissingFiles = (
        local items = undefined
        local logMessage = undefined
        local uniqueMissingMaps = undefined
        local uniqueMissingModels = undefined
        
        try (
            local startTime = timestamp()
            -- 初始化 missingMaps
            g_resourceManager.setMissingMaps #()
            
            if lvModels != undefined do (
                lvModels.Items.Clear()
                lvModels.BeginUpdate()
            )
            
            local totalModels = geometry.count
            local totalMaps = 0
            local missingModelsCount = 0
            local missingMapsCount = 0
            local invalidSizeCount = 0
            uniqueMissingMaps = #()
            uniqueMissingModels = #()

            -- 检查是否启用贴图大小检测
            local checkSize = chkMapSizeCheck.checked

            for obj in geometry do (
                if obj.material != undefined do (
                    local mat = obj.material
                    if classof mat == Multimaterial then (
                        for i = 1 to mat.numsubs do (
                            local subMat = mat[i]
                            if subMat != undefined then (
                                local diffuseMap = case classof subMat of (
                                    StandardMaterial: subMat.diffuseMap
                                    VRayMtl: subMat.texmap_diffuse
                                    PhysicalMaterial: subMat.base_color_map
                                    default: undefined
                                )
                                
                                if diffuseMap != undefined then (
                                    totalMaps += 1
                                    local fileName = diffuseMap.filename
                                    if fileName != "" then (
                                        if not doesFileExist fileName then (
                                            -- 处理丢失贴图...
                                            local fileBaseName = getFilenameFile fileName
                                            local fileExtension = getFilenameType fileName
                                            local currentMissingMaps = g_resourceManager.getMissingMaps()
                                            append currentMissingMaps #(obj.name, subMat.name, i, fileBaseName + fileExtension)
                                            g_resourceManager.setMissingMaps currentMissingMaps
                                            
                                            if findItem uniqueMissingMaps (fileBaseName + fileExtension) == 0 do (
                                                append uniqueMissingMaps (fileBaseName + fileExtension)
                                                missingMapsCount += 1
                                            )
                                            
                                            if findItem uniqueMissingModels obj.name == 0 do (
                                                append uniqueMissingModels obj.name
                                                missingModelsCount += 1
                                            )
                                        ) else if checkSize do (
                                            -- 检查贴图尺寸
                                            local sizeCheck = optimizedCheckTextureSize fileName
                                            if not sizeCheck[1] do (
                                                local listItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                                                listItem.SubItems.Add subMat.name
                                                listItem.SubItems.Add (i as string)
                                                listItem.SubItems.Add (filenameFromPath fileName)
                                                listItem.SubItems.Add sizeCheck[2]
                                                listItem.ForeColor = (dotNetClass "System.Drawing.Color").Black
                                                lvModels.Items.Add listItem
                                                invalidSizeCount += 1
                                            )
                                            cleanupBitmap bmap
                                        )
                                    )
                                )
                            )
                        )
                    ) else (
                        local diffuseMap = case classof mat of (
                            StandardMaterial: mat.diffuseMap
                            VRayMtl: mat.texmap_diffuse
                            PhysicalMaterial: mat.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined then (
                            totalMaps += 1
                            local fileName = diffuseMap.filename
                            if fileName != "" then (
                                if not doesFileExist fileName then (
                                    -- 处理丢失贴图...
                                    local fileBaseName = getFilenameFile fileName
                                    local fileExtension = getFilenameType fileName
                                    local currentMissingMaps = g_resourceManager.getMissingMaps()
                                    append currentMissingMaps #(obj.name, mat.name, 1, fileBaseName + fileExtension)
                                    g_resourceManager.setMissingMaps currentMissingMaps
                                    
                                    if findItem uniqueMissingMaps (fileBaseName + fileExtension) == 0 do (
                                        append uniqueMissingMaps (fileBaseName + fileExtension)
                                        missingMapsCount += 1
                                    )
                                    
                                    if findItem uniqueMissingModels obj.name == 0 do (
                                        append uniqueMissingModels obj.name
                                        missingModelsCount += 1
                                    )
                                ) else if checkSize do (
                                    -- 检查贴图尺寸
                                    local bmap = openBitMap fileName
                                    local sizeCheck = checkTextureSize bmap
                                    if not sizeCheck[1] do (
                                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                                        listItem.SubItems.Add mat.name
                                        listItem.SubItems.Add "1"
                                        listItem.SubItems.Add (filenameFromPath fileName)
                                        listItem.SubItems.Add sizeCheck[2]
                                        listItem.ForeColor = (dotNetClass "System.Drawing.Color").Black
                                        lvModels.Items.Add listItem
                                        invalidSizeCount += 1
                                    )
                                    cleanupBitmap bmap
                                )
                            )
                        )
                    )
                )
            )

            -- 更新列表显示丢失的贴图
            local currentMissingMaps = g_resourceManager.getMissingMaps()
            for map in currentMissingMaps do (
                local item = dotNetObject "System.Windows.Forms.ListViewItem" map[1]
                item.SubItems.Add map[2]
                item.SubItems.Add (map[3] as string)
                item.SubItems.Add map[4]
                item.SubItems.Add "贴图丢失"
                item.ForeColor = (dotNetClass "System.Drawing.Color").Black
                lvModels.Items.Add item
            )

            lvModels.EndUpdate()

            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0

            -- 生成日志信息
            logMessage = stringStream ""
            format "------------------------ \r\n" to:logMessage
            if missingMaps.count == 0 and invalidSizeCount == 0 then (
                format "未发现问题。\r\n" to:logMessage
            )
            format "总模型数: %个\r\n总贴图数: %张\r\n" totalModels totalMaps to:logMessage
            format "丢失模型数: %个\r\n丢失贴图数: %张\r\n" missingModelsCount missingMapsCount to:logMessage
            if checkSize then (
                format "非2次幂贴图数: % 张\r\n" invalidSizeCount to:logMessage
            )
            format "检查耗时: %秒\r\n" elapsedTime to:logMessage
            format "###########$$$########## \r\n" to:logMessage

            insertLog (logMessage as string)
            
        ) catch (
            messageBox ("检查贴图时发生错误：" + (getCurrentException())) title:"错误"
        ) finally (
            -- 清理资源
            if items != undefined do items = undefined
            if logMessage != undefined do (
                try(free logMessage)catch()
                logMessage = undefined
            )
            if uniqueMissingMaps != undefined do uniqueMissingMaps = undefined
            if uniqueMissingModels != undefined do uniqueMissingModels = undefined
            gc light:true
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
                local materialCount = 0
                if selectedObj.material != undefined then
                (
                    if classof selectedObj.material == MultiMaterial then
                        materialCount = selectedObj.material.numsubs
                    else
                        materialCount = 1
                )
                
                local quadFaceCount = 0

                if isKindOf selectedObj Editable_Poly then
                (
                    quadFaceCount = polyOp.getNumFaces selectedObj
                )
                else if isKindOf selectedObj Editable_Mesh then
                (
                    triFaceCount = selectedObj.numFaces
                )

                edtModelInfo.text = "名: " + selectedObj.name + "\r\n材质ID数量: " + materialCount as string + "个\r\n四边面数: " + quadFaceCount as string + "面"
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
    on btnCheck pressed do (
        if g_resourceManager.getIsProcessing() do return()
        g_resourceManager.setIsProcessing true
        disableButton btnCheck
        
        try (
            -- 清空列表并开始更新
            lvModels.Items.Clear()
            lvModels.BeginUpdate()
            
            -- 确保 missingMaps 数组已初始化
            if missingMaps == undefined do missingMaps = #()
            
            -- 遍历场景中的所有几何体
            local totalModels = geometry.count
            local totalMaps =0
            local missingCount = 0
            local invalidSizeCount = 0
            
            -- 获取是否启用贴图大小检测
            local checkSize = chkMapSizeCheck.checked
            
            for obj in geometry do (
                if obj.material != undefined then (
                    if classof obj.material == MultiMaterial then (
                        -- 处理多重材质
                        for i = 1 to obj.material.numsubs do (
                            local subMat = obj.material[i]
                            if subMat != undefined then (
                                local diffuseMap = case classof subMat of (
                                    StandardMaterial: subMat.diffuseMap
                                    VRayMtl: subMat.texmap_diffuse
                                    PhysicalMaterial: subMat.base_color_map
                                    default: undefined
                                )
                                
                                if diffuseMap != undefined then (
                                    totalMaps += 1
                                    local fileName = diffuseMap.filename
                                    
                                    if not doesFileExist fileName then (
                                        -- 处理丢失贴图
                                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                                        listItem.SubItems.Add subMat.name
                                        listItem.SubItems.Add (i as string)
                                        listItem.SubItems.Add (filenameFromPath fileName)
                                        listItem.SubItems.Add "贴图丢失"
                                        lvModels.Items.Add listItem
                                        
                                        append missingMaps #(obj.name, subMat.name, i, filenameFromPath fileName)
                                        missingCount += 1
                                    ) else if checkSize do (
                                        try (
                                            local sizeCheck = optimizedCheckTextureSize fileName
                                            if sizeCheck != undefined and not sizeCheck[1] do (
                                                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                                                        listItem.SubItems.Add subMat.name
                                                        listItem.SubItems.Add (i as string)
                                                        listItem.SubItems.Add (filenameFromPath fileName)
                                                        listItem.SubItems.Add ("非2次幂: " + sizeCheck[2])
                                                        lvModels.Items.Add listItem
                                                        invalidSizeCount += 1
                                                    )
                                                ) catch (
                                                    format "检查贴图尺寸时出错: %\n" (getCurrentException())
                                                )
                                            
                                    )
                                )
                            )
                        )
                    ) else (
                        -- 处理单一材质
                        local diffuseMap = case classof obj.material of (
                            StandardMaterial: obj.material.diffuseMap
                            VRayMtl: obj.material.texmap_diffuse
                            PhysicalMaterial: obj.material.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined then (
                            totalMaps += 1
                            local fileName = diffuseMap.filename
                            
                            if not doesFileExist fileName then (
                                -- 处理丢失贴图
                                local listItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                                listItem.SubItems.Add obj.material.name
                                listItem.SubItems.Add "1"
                                listItem.SubItems.Add (filenameFromPath fileName)
                                listItem.SubItems.Add "贴图丢失"
                                lvModels.Items.Add listItem
                                
                                append missingMaps #(obj.name, obj.material.name, 1, filenameFromPath fileName)
                                missingCount += 1
                            ) else if checkSize do (
                                try (
                                    local sizeCheck = optimizedCheckTextureSize fileName
                                    if sizeCheck != undefined and not sizeCheck[1] do (
                                                local listItem = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                                                listItem.SubItems.Add obj.material.name
                                                listItem.SubItems.Add "1"
                                                listItem.SubItems.Add (filenameFromPath fileName)
                                                listItem.SubItems.Add ("非2次幂: " + sizeCheck[2])
                                                lvModels.Items.Add listItem
                                                invalidSizeCount += 1
                                            )
                                        ) catch (
                                            format "检查贴图尺寸时出错: %\n" (getCurrentException())
                                        )
                                    
                            )
                        )
                    )
                )
            )
            
            -- 恢复列表更新
            lvModels.EndUpdate()
            
            -- 生成日志信息
            local logMessage = "------------------------ \r\n"
            logMessage += "检查完成\r\n"
            logMessage += "总模型数: " + totalModels as string + "\r\n"
            logMessage += "总贴图数: " + totalMaps as string + "\r\n"
            logMessage += "丢失贴图数: " + missingCount as string + "\r\n"
            if checkSize then (
                logMessage += "非2次幂贴图数: " + invalidSizeCount as string + "\r\n"
            )
            logMessage += "------------------------ \r\n"
            insertLog logMessage
            
        ) catch (
            messageBox ("检查贴图时发生错误：" + (getCurrentException())) title:"错误"
        )
        
        g_resourceManager.setIsProcessing false
        enableButton btnCheck
    )

    -- 替换按钮点击事件
    on btnReplace pressed do (
        try (
            -- 初始化计数器
            local successCount = 0
            local failCount = 0
            
            -- 禁用按钮防止重复点击
            disableButton btnReplace
            
            -- 检查是否有选中的项目
            if lvModels.SelectedItems.Count > 0 then (
                -- 处理选中项
                selectedFile = getOpenFileName caption:"选择替换贴图" \
                    types:"图像文件(*.jpg;*.png;*.tga)|*.jpg;*.png;*.tga|所有文件(*.*)|*.*|"
                
                if selectedFile != undefined then (
                    -- 遍历选中的项目
                    for i = 0 to lvModels.SelectedItems.Count - 1 do (
                        try (
                            local selectedItem = lvModels.SelectedItems.Item[i]
                            local objName = selectedItem.Text
                            local matName = selectedItem.SubItems.Item[1].Text
                            local matID = try(selectedItem.SubItems.Item[2].Text as integer)catch(1)
                            
                            -- 获取对象
                            local obj = getNodeByName objName
                            if obj != undefined and obj.material != undefined then (
                                if classof obj.material == MultiMaterial then (
                                    -- 处理多重材质
                                    if matID > 0 and matID <= obj.material.numsubs then (
                                        local subMat = obj.material[matID]
                                        if subMat != undefined then (
                                            local diffuseMap = case classof subMat of (
                                                StandardMaterial: subMat.diffuseMap
                                                VRayMtl: subMat.texmap_diffuse
                                                PhysicalMaterial: subMat.base_color_map
                                                default: undefined
                                            )
                                            
                                            if diffuseMap != undefined then (
                                                diffuseMap.filename = selectedFile
                                                successCount += 1
                                                -- 更新列表项状态
                                                selectedItem.SubItems.Item[4].Text = "替换成功"
                                            ) else (
                                                failCount += 1
                                                selectedItem.SubItems.Item[4].Text = "无贴图通道"
                                            )
                                        ) else (
                                            failCount += 1
                                            selectedItem.SubItems.Item[4].Text = "材质ID无效"
                                        )
                                    )
                                ) else (
                                    -- 处理单一材质
                                    local diffuseMap = case classof obj.material of (
                                        StandardMaterial: obj.material.diffuseMap
                                        VRayMtl: obj.material.texmap_diffuse
                                        PhysicalMaterial: obj.material.base_color_map
                                        default: undefined
                                    )
                                    
                                    if diffuseMap != undefined then (
                                        diffuseMap.filename = selectedFile
                                        successCount += 1
                                        selectedItem.SubItems.Item[4].Text = "替换成功"
                                    ) else (
                                        failCount += 1
                                        selectedItem.SubItems.Item[4].Text = "无贴图通道"
                                    )
                                )
                            ) else (
                                failCount += 1
                                selectedItem.SubItems.Item[4].Text = "对象或材质无效"
                            )
                        ) catch (
                            failCount += 1
                            format "处理对象时出错: %\n" (getCurrentException())
                        )
                    )
                )
            ) else (
                -- 如果没有选中项，则检查所有丢失的贴图
                checkMissingFiles()
                
                -- 检查完成后，如果没有丢失的贴图则提示并返回
                local currentMissingMaps = g_resourceManager.getMissingMaps()
                if currentMissingMaps.count == 0 then (
                    messageBox "未检测到能替换的贴图！" title:"提示"
                    enableButton btnReplace
                    return undefined
                )
                
                selectedFile = getOpenFileName caption:"选择替换贴图" \
                    types:"图像文件(*.jpg;*.png;*.tga)|*.jpg;*.png;*.tga|所有文件(*.*)|*.*|"
                
                if selectedFile != undefined then (
                    -- 使用临时数组存储需要处理的对象
                    local mapsToProcess = #()
                    join mapsToProcess (g_resourceManager.getMissingMaps())
                    
                    for map in mapsToProcess do (
                        try (
                            local obj = getNodeByName map[1]
                            if obj != undefined and obj.material != undefined then (
                                if classof obj.material == MultiMaterial then (
                                    local subMat = obj.material[map[3]]
                                    if subMat != undefined then (
                                        local diffuseMap = case classof subMat of (
                                            StandardMaterial: subMat.diffuseMap
                                            VRayMtl: subMat.texmap_diffuse
                                            PhysicalMaterial: subMat.base_color_map
                                            default: undefined
                                        )
                                        
                                        if diffuseMap != undefined then (
                                            diffuseMap.filename = selectedFile
                                            successCount += 1
                                        ) else failCount += 1
                                    ) else failCount += 1
                                ) else (
                                    local diffuseMap = case classof obj.material of (
                                        StandardMaterial: obj.material.diffuseMap
                                        VRayMtl: obj.material.texmap_diffuse
                                        PhysicalMaterial: obj.material.base_color_map
                                        default: undefined
                                    )
                                    
                                    if diffuseMap != undefined then (
                                        diffuseMap.filename = selectedFile
                                        successCount += 1
                                    ) else failCount += 1
                                )
                            )
                        ) catch (
                            failCount += 1
                            format "处理对象时出错: %\n" (getCurrentException())
                        )
                    )
                    
                    -- 清理临时数组
                    mapsToProcess = undefined
                )
            )
            
            -- 生成日志信息
            if selectedFile != undefined then (
                local logMessage = "------------------------ \r\n"
                logMessage += "替换完成\r\n"
                logMessage += "成功替换: " + successCount as string + "个\r\n"
                if failCount > 0 then (
                    logMessage += "替换失败: " + failCount as string + "个\r\n"
                )
                logMessage += "------------------------ \r\n"
                insertLog logMessage
                
                -- 刷新检查结果
                checkMissingFiles()
            )
            
            -- 清理资源
            selectedFile = undefined
            gc light:true
            
        ) catch (
            messageBox ("替换贴图时发生错误：" + (getCurrentException())) title:"错误"
        )
        
        
        enableButton btnReplace
    )

    -- 更换贴图路径按钮事件
    on btnChangePath pressed do (
        try (
            -- 禁用按钮，防止重复点击
            disableButton btnChangePath
            
            -- 收集需要处理的项目
            local itemsToProcess = if lvModels.SelectedItems.Count > 0 then (
                -- 收集选中项的信息
                for i = 0 to lvModels.SelectedItems.Count - 1 collect (
                    local item = lvModels.SelectedItems.Item[i]
                    #(item.Text, item.SubItems.Item[1].Text, try(item.SubItems.Item[2].Text as integer)catch(1))
                )
            ) else (
                
                checkMissingFiles()
                g_resourceManager.getMissingMaps()
            )
            
            -- 检查是否有需要处理的项目
            if itemsToProcess.count == 0 then (
                messageBox "列表中未检测到丢失贴图的模型。" title:"提示"
                enableButton btnChangePath
                return undefined
            )
            
            -- 选择新路径
            local newPath = getSavePath caption:"选择新的贴图路径"
            if newPath != undefined do (
                local startTime = timestamp()
                local processedCount = 0
                local failedCount = 0
                local uniquePaths = #()
                local pathUpdates = #()
                
                -- 使用 with redraw off 来减少重绘
                with redraw off (
                    -- 批量处理所有对象
                    for itemInfo in itemsToProcess do (
                        local obj = getNodeByName itemInfo[1]
                        if obj != undefined and obj.material != undefined then (
                            if classof obj.material == MultiMaterial then (
                                -- 处理多重材质
                                local matID = itemInfo[3]
                                if matID > 0 and matID <= obj.material.numsubs then (
                                    local subMat = obj.material[matID]
                                    if subMat != undefined then (
                                        local diffuseMap = case classof subMat of (
                                            StandardMaterial: subMat.diffuseMap
                                            VRayMtl: subMat.texmap_diffuse
                                            PhysicalMaterial: subMat.base_color_map
                                            default: undefined
                                        )
                                        
                                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                            local currentPath = diffuseMap.filename
                                            local fileName = filenameFromPath currentPath
                                            local newFilePath = newPath + "\\" + fileName
                                            append pathUpdates #(diffuseMap, currentPath, newFilePath)
                                        )
                                    )
                                )
                            ) else (
                                -- 处理单一材质
                                local diffuseMap = case classof obj.material of (
                                    StandardMaterial: obj.material.diffuseMap
                                    VRayMtl: obj.material.texmap_diffuse
                                    PhysicalMaterial: obj.material.base_color_map
                                    default: undefined
                                )
                                
                                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                    local currentPath = diffuseMap.filename
                                    local fileName = filenameFromPath currentPath
                                    local newFilePath = newPath + "\\" + fileName
                                    append pathUpdates #(diffuseMap, currentPath, newFilePath)
                                )
                            )
                        )
                    )
                    
                    -- 批量更新贴图路径
                    for update in pathUpdates do (
                        try (
                            local diffuseMap = update[1]
                            local oldPath = update[2]
                            local newFilePath = update[3]
                            
                            -- 检查是否已处理过该路径
                            if findItem uniquePaths oldPath == 0 then (
                                append uniquePaths oldPath
                                -- 复制文件（如果存在）
                                if doesFileExist oldPath then (
                                    try(copyFile oldPath newFilePath)catch()
                                )
                            )
                            
                            -- 更新贴图路径
                            diffuseMap.filename = newFilePath
                            processedCount += 1
                        ) catch (
                            failedCount += 1
                        )
                    )
                )
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = "------------------------ \r\n"
                logMessage += "路径更新完成\r\n"
                logMessage += "更新模式: 丢失贴图\r\n"
                logMessage += "处理贴图数: " + processedCount as string + "\r\n"
                if failedCount > 0 then (
                    logMessage += "失败数量: " + failedCount as string + "\r\n"
                )
                logMessage += "新路径: " + newPath + "\r\n"
                logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                logMessage += "------------------------ \r\n"
                insertLog logMessage
                
                -- 刷新检查结果
                checkMissingFiles()
            )
        ) catch (
            messageBox ("更换贴图路径时发生错误：" + (getCurrentException())) title:"错误"
        )
        
        -- 重新启用按钮
        enableButton btnChangePath
    )

    -- 添加右键点击事件
    on btnChangePath rightClick do (
        try (
            -- 禁用按钮，防止重复点击
            disableButton btnChangePath
            
            -- 右键点击时处理所有对象
            local itemsToProcess = for obj in geometry where not obj.isHidden collect (
                #(obj.name, "", 1) -- 使用相同的数据结构,但简化内容
            )
            
            -- 检查是否有需要处理的项目
            if itemsToProcess.count == 0 then (
                messageBox "场景中没有可处理的模型。" title:"提示"
                enableButton btnChangePath
                return undefined
            )
            
            -- 选择新路径
            local newPath = getSavePath caption:"选择新的贴图路径"
            if newPath != undefined do (
                -- 其余处理代码与左键相同...
                local startTime = timestamp()
                local processedCount = 0
                local failedCount = 0
                local uniquePaths = #()
                local pathUpdates = #()
                
                -- 使用 with redraw off 来减少重绘
                with redraw off (
                    -- 批量处理所有对象
                    for itemInfo in itemsToProcess do (
                        local obj = getNodeByName itemInfo[1]
                        if obj != undefined and obj.material != undefined then (
                            if classof obj.material == MultiMaterial then (
                                -- 处理多重材质
                                local matCount = obj.material.numsubs
                                -- 处理所有子材质
                                for i = 1 to matCount do (
                                    local subMat = obj.material[i]
                                    if subMat != undefined then (
                                        local diffuseMap = case classof subMat of (
                                            StandardMaterial: subMat.diffuseMap
                                            VRayMtl: subMat.texmap_diffuse
                                            PhysicalMaterial: subMat.base_color_map
                                            default: undefined
                                        )
                                        
                                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                            local currentPath = diffuseMap.filename
                                            local fileName = filenameFromPath currentPath
                                            local newFilePath = newPath + "\\" + fileName
                                            append pathUpdates #(diffuseMap, currentPath, newFilePath)
                                        )
                                    )
                                )
                            ) else (
                                -- 处理单一材质
                                local diffuseMap = case classof obj.material of (
                                    StandardMaterial: obj.material.diffuseMap
                                    VRayMtl: obj.material.texmap_diffuse
                                    PhysicalMaterial: obj.material.base_color_map
                                    default: undefined
                                )
                                
                                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                    local currentPath = diffuseMap.filename
                                    local fileName = filenameFromPath currentPath
                                    local newFilePath = newPath + "\\" + fileName
                                    append pathUpdates #(diffuseMap, currentPath, newFilePath)
                                )
                            )
                        )
                    )
                    
                    -- 批量更新贴图路径
                    for update in pathUpdates do (
                        try (
                            local diffuseMap = update[1]
                            local oldPath = update[2]
                            local newFilePath = update[3]
                            
                            -- 检查是否已处理过该路径
                            if findItem uniquePaths oldPath == 0 then (
                                append uniquePaths oldPath
                                -- 复制文件（如果存在）
                                if doesFileExist oldPath then (
                                    try(copyFile oldPath newFilePath)catch()
                                )
                            )
                            
                            -- 更新贴图路径
                            diffuseMap.filename = newFilePath
                            processedCount += 1
                        ) catch (
                            failedCount += 1
                        )
                    )
                )
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = "------------------------ \r\n"
                logMessage += "路径更新完成\r\n"
                logMessage += "更新模式: 全部贴图\r\n"
                logMessage += "处理贴图数: " + processedCount as string + "\r\n"
                if failedCount > 0 then (
                    logMessage += "失败数量: " + failedCount as string + "\r\n"
                )
                logMessage += "新路径: " + newPath + "\r\n"
                logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                logMessage += "------------------------ \r\n"
                insertLog logMessage
                
                -- 刷新检查结果
                checkMissingFiles()
            )
        ) catch (
            messageBox ("更换贴图路径发生错误：" + (getCurrentException())) title:"错误"
        )
        
        -- 重新启用按钮
        enableButton btnChangePath
    )

    -- 递归函数，用于转材质
    fn copyCommonProperties sourceMtl targetMtl = (
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

    fn convertMaterial mtl targetType = (
        try (
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
        catch (
            print ("Error converting material: " + (getCurrentException()))
            mtl -- 返回原始材质，如果转失败
        )
    )
    -- 清除日志按钮点击事件
    on btnClearLog pressed do (
        edtLog.Clear()
    )

    -- 转化为标准材质按钮点击事件
    on btnConvertToStandard pressed do (
        if g_resourceManager.getIsProcessing() do return()
        g_resourceManager.setIsProcessing true
        disableButton btnConvertToStandard
        try (
            local startTime = timestamp()
            local totalCount = scenematerials.count
            local convertedCount = 0

            -- 遍历场景的所有材质
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
            logMessage += "转换标准材质完成\r\n"
            logMessage += "总材质数: " + totalCount as string + "\r\n"
            logMessage += "转换材质数: " + convertedCount as string + "\r\n"
            logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
            logMessage += "<<暂时请勿操作:请等待2秒>>\r\n"
            logMessage += "------------------------ \r\n"
            insertLog logMessage clearPrevious:true
        ) catch (
            messageBox ("转换质时发生错误：" + (getCurrentException())) title:"错误"
        )
        g_resourceManager.setIsProcessing false
        enableButton btnConvertToStandard
    )

    -- 转化为VR材质按钮点击事件
    on btnConvertToVR pressed do (
        if g_resourceManager.getIsProcessing() do return()
        g_resourceManager.setIsProcessing true
        disableButton btnConvertToVR
        try (
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
            insertLog logMessage clearPrevious:true
        ) catch (
            messageBox ("转换材质时发生错误：" + (getCurrentException())) title:"错误"
        )
        g_resourceManager.setIsProcessing false
        enableButton btnConvertToVR
    )

    -- 添加重命名弹窗rollout
    rollout renameRollout "重命名工具" width:550 height:450
    (
        local closeTimer = undefined
        -- 用于存储排除的贴图路径
        local excludedTextures = #()
        -- 用于存储场景中所有贴图的路径
        local allTextures = #()
        
        -- 添加计时器创建函数
        fn createCloseTimer = (
            try (
                local timer = dotNetObject "System.Windows.Forms.Timer"
                timer.Interval = 1000 -- 1秒
                
                -- 创建委托和事件处理
                local callback = dotNetClass "System.EventHandler"
                local timerCallback = dotNetObject callback timer (fn timerCallback sender args = (
                    try(
                        sender.Stop()
                        destroyDialog renameRollout
                        sender.Dispose()
                    )catch()
                ))
                
                -- 使用委托添加事件处理
                timer.add_Tick timerCallback
                
                return timer
            ) catch (
                format "创建计时器失败: %\n" (getCurrentException())
                return undefined
            )
        )

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
        label lbl4 "姓名写" pos:[260,35] width:60 height:20 textColor:labelColor
        label plus4 "+" pos:[330,60] width:10 height:10 textColor:labelColor
        label lbl5 "起始位" pos:[340,35] width:40 height:20 textColor:labelColor
        
        -- 模型命名输入框行
        editText base1 "" pos:[20,55] width:60 height:20 text:"SM" align:#center tooltip:"模型名称的基础代号(如SM代表静态模型)"
        editText city1 "" pos:[100,55] width:60 height:20 align:#center tooltip:"模型所属城市的简称"
        editText proj1 "" pos:[180,55] width:60 height:20 align:#center tooltip:"项目名称的简写"
        editText abbr1 "" pos:[260,55] width:60 height:20 align:#center tooltip:"创建者姓名的缩写"
        spinner start1 "" pos:[340,55] width:40 height:30 range:[0,999,1] type:#integer scale:1 tooltip:"重命名起始序号"
        
        -- 选择和填充位
        radioButtons rad1 "" pos:[20,83] width:150 height:20 labels:#("选择", "全部") columns:2 tooltip:"选择重命名模式：仅选中的模型或全部模型"
        label fill1 "填充位:" pos:[300,80] width:40 height:20 textColor:labelColor
        spinner fillNum1 "" pos:[340,80] width:40 height:30 range:[0,10,3] type:#integer scale:1 tooltip:"序号的填充位数，如001表示3位"
        checkbox chk_enableRename "启用模型命名" pos:[120,80] width:90 height:20 tooltip:"勾选此项启用模型重命名功能"
        
        -- 贴图命名组
        GroupBox grp2 "贴图命名" pos:[10,120] width:400 height:100    
        -- 贴图命名标签行
        label lbl6 "基础代号" pos:[20,145] width:60 height:20 textColor:labelColor
        label plus5 "+" pos:[90,165] width:10 height:20 textColor:labelColor
        label lbl7 "城市名称" pos:[100,145] width:60 height:20 textColor:labelColor
        label plus6 "+" pos:[170,165] width:10 height:20 textColor:labelColor
        label lbl8 "项目名称" pos:[180,145] width:60 height:20 textColor:labelColor
        label plus7 "+" pos:[250,165] width:10 height:20 textColor:labelColor
        label lbl9 "姓名简写" pos:[260,145] width:60 height:20 textColor:labelColor
        label plus8 "+" pos:[330,165] width:10 height:20 textColor:labelColor
        label lbl10 "起始位" pos:[340,145] width:40 height:20 textColor:labelColor
        
        -- 贴图命名输入框行
        editText base2 "" pos:[20,165] width:60 height:20 text:"T" align:#center tooltip:"贴图名称的基础代号(如T代表贴图)"
        editText city2 "" pos:[100,165] width:60 height:20 align:#center tooltip:"贴图所属城市的简称"
        editText proj2 "" pos:[180,165] width:60 height:20 align:#center tooltip:"项目名称的简写"
        editText abbr2 "" pos:[260,165] width:60 height:20 align:#center tooltip:"创建者姓名的缩写"
        spinner start2 "" pos:[340,165] width:40 height:30 range:[0,999,1] type:#integer scale:1 tooltip:"重命名起始序号"
        
        -- 选择和填充位
        radioButtons rad2 "" pos:[20,193] width:150 height:20 labels:#("选择", "全部") columns:2 tooltip:"选择重命名模式：仅选中模型的贴图或全部贴图"
        label fill2 "填充位:" pos:[300,190] width:40 height:20 textColor:labelColor
        spinner fillNum2 "" pos:[340,190] width:40 height:30 range:[0,10,3] type:#integer scale:1 tooltip:"序号的填充位数，如001表示3位"
        checkbox chk_enableTextureRename "启用贴图命名" pos:[120,190] width:90 height:20 checked:false tooltip:"勾选此项启用贴图重命名功能"
        
        -- 贴图排除功能组 (新增)
        GroupBox grpExclude "贴图排除" pos:[10,230] width:530 height:200
        
        -- 场景贴图列表 (左侧)
        label lblAllTextures "场景贴图:" pos:[20,250] width:80 height:20 textColor:labelColor
        listbox lbAllTextures "" pos:[20,270] width:220 height:10 tooltip:"场景中所有贴图"
        
        -- 排除贴图列表 (右侧)
        label lblExcludedTextures "排除贴图:" pos:[310,250] width:80 height:20 textColor:labelColor
        listbox lbExcludedTextures "" pos:[310,270] width:220 height:10 tooltip:"这些贴图将不会被重命名"
        
        -- 操作按钮
        button btnExclude ">>" pos:[250,290] width:50 height:25 tooltip:"将选中的贴图添加到排除列表"
        button btnInclude "<<" pos:[250,330] width:50 height:25 tooltip:"将选中的贴图从排除列表中移除"
        button btnRefreshTextures "刷新贴图列表" pos:[220,400] width:100 height:25 tooltip:"刷新场景中的贴图列表"
        
        -- 底部按钮
        button renameBtn "开始" pos:[420,15] width:120 height:30 tooltip:"执行勾选模块的功能"
        button useTextureBtn "将贴图名称作为材质名称" pos:[420,50] width:120 height:40 tooltip:"根据贴图名称自动设置材质名称"
        checkBox chkArchive "将贴图归档" pos:[440,90] width:80 height:20 tooltip:"勾选后会将贴图复制到场景文件同级目录下的maps文件夹中"
        checkBox chkAllowEmpty "允许空输入" pos:[440,110] width:80 height:20 tooltip:"勾选后允许某些输入框为空，重命名时将忽略空输入框"
        
        -- 获取场景中所有贴图路径的函数
        fn collectSceneTextures = (
            local result = #()
            local processed = #()
            
            for mat in sceneMaterials do (
                if classof mat == Multimaterial then (
                    -- 处理多重材质
                    for i = 1 to mat.numsubs do (
                        local subMat = mat[i]
                        if subMat != undefined then (
                            local diffuseMap = case classof subMat of (
                                StandardMaterial: subMat.diffuseMap
                                VRayMtl: subMat.texmap_diffuse
                                PhysicalMaterial: subMat.base_color_map
                                default: undefined
                            )
                            
                            if diffuseMap != undefined and diffuseMap.filename != undefined and diffuseMap.filename != "" then (
                                if findItem processed diffuseMap.filename == 0 then (
                                    append processed diffuseMap.filename
                                    append result diffuseMap.filename
                                )
                            )
                        )
                    )
                ) else (
                    -- 处理单一材质
                    local diffuseMap = case classof mat of (
                        StandardMaterial: mat.diffuseMap
                        VRayMtl: mat.texmap_diffuse
                        PhysicalMaterial: mat.base_color_map
                        default: undefined
                    )
                    
                    if diffuseMap != undefined and diffuseMap.filename != undefined and diffuseMap.filename != "" then (
                        if findItem processed diffuseMap.filename == 0 then (
                            append processed diffuseMap.filename
                            append result diffuseMap.filename
                        )
                    )
                )
            )
            
            return result
        )
        
        -- 更新贴图列表显示
        fn updateTextureListsDisplay = (
            -- 清空列表
            lbAllTextures.items = #()
            lbExcludedTextures.items = #()
            
            -- 添加非排除贴图到左侧列表
            for texPath in allTextures do (
                if findItem excludedTextures texPath == 0 then (
                    -- 只显示文件名，不显示完整路径
                    local texName = filenameFromPath texPath
                    lbAllTextures.items = append lbAllTextures.items texName
                )
            )
            
            -- 添加排除贴图到右侧列表
            for texPath in excludedTextures do (
                -- 只显示文件名，不显示完整路径
                local texName = filenameFromPath texPath
                lbExcludedTextures.items = append lbExcludedTextures.items texName
            )
        )
        
        -- 获取选中贴图的完整路径
        fn getSelectedTexturePath fromList selectedIndex = (
            local textures = if fromList == lbAllTextures then (
                for texPath in allTextures where findItem excludedTextures texPath == 0 collect texPath
            ) else (
                excludedTextures
            )
            
            if selectedIndex > 0 and selectedIndex <= textures.count then (
                return textures[selectedIndex]
            )
            
            return undefined
        )
        
        -- 初始化
        on renameRollout open do (
            -- 收集场景中的所有贴图
            allTextures = collectSceneTextures()
            
            -- 更新列表显示
            updateTextureListsDisplay()
        )
        
        -- 刷新贴图列表按钮事件
        on btnRefreshTextures pressed do (
            -- 重新收集场景中的所有贴图
            allTextures = collectSceneTextures()
            
            -- 清理排除列表中不存在的贴图
            excludedTextures = for texPath in excludedTextures where findItem allTextures texPath > 0 collect texPath
            
            -- 更新列表显示
            updateTextureListsDisplay()
        )
        
        -- 排除贴图按钮事件
        on btnExclude pressed do (
            local selectedIndex = lbAllTextures.selection
            if selectedIndex > 0 then (
                local texPath = getSelectedTexturePath lbAllTextures selectedIndex
                if texPath != undefined and findItem excludedTextures texPath == 0 then (
                    append excludedTextures texPath
                    updateTextureListsDisplay()
                )
            )
        )
        
        -- 取消排除按钮事件
        on btnInclude pressed do (
            local selectedIndex = lbExcludedTextures.selection
            if selectedIndex > 0 then (
                local texPath = getSelectedTexturePath lbExcludedTextures selectedIndex
                if texPath != undefined and findItem excludedTextures texPath > 0 then (
                    excludedTextures = for p in excludedTextures where p != texPath collect p
                    updateTextureListsDisplay()
                )
            )
        )
        
        -- 重命名按钮事件
        on renameBtn pressed do (
            try (
                local hasValidOperation = false
                
                -- 模型重命名功能
                if chk_enableRename.checked then (
                    -- 检查必填字段
                    local fieldsValid = true
                    
                    if not chkAllowEmpty.checked then (
                        -- 如果不允许空输入框，检查所有字段是否都已填写
                        if base1.text == "" or city1.text == "" or proj1.text == "" or abbr1.text == "" then (
                            fieldsValid = false
                        )
                    ) else (
                        -- 如果允许空输入框，检查是否至少有一个字段填写了值
                        if base1.text == "" and city1.text == "" and proj1.text == "" and abbr1.text == "" then (
                            fieldsValid = false
                        )
                    )
                    
                    if fieldsValid then (
                        hasValidOperation = true
                        local startTime = timestamp()
                        local processedCount = 0
                        
                        -- 获取输入值并确保它们都有效
                        local baseCode = if base1.text != "" then base1.text else ""
                        local cityName = if city1.text != "" then city1.text else ""
                        local projName = if proj1.text != "" then proj1.text else ""
                        local abbrName = if abbr1.text != "" then abbr1.text else ""
                        local startNumber = try(start1.value as integer)catch(1)
                        local fillWidth = try(fillNum1.value as integer)catch(3)
                        
                        -- 获取要处理的对象数组
                        local objsToProcess = #()
                        if rad1.state == 1 then (
                            objsToProcess = selection as array
                            if objsToProcess.count == 0 then (
                                messageBox "请先选择要处理的对象！" title:"提示"
                                return undefined
                            )
                        ) else (
                            for obj in geometry where not obj.isHidden do (
                                append objsToProcess obj
                            )
                        )
                        
                        -- 执行模型重命名
                        local result = renameModels baseCode cityName projName abbrName startNumber fillWidth objsToProcess
                        processedCount = result[1]
                        
                        local endTime = timestamp()
                        local elapsedTime = (endTime - startTime) / 1000.0
                        
                        -- 生成日志信息
                        local logMessage = "------------------------ \r\n"
                        logMessage += "模型重命名完成\r\n"
                        logMessage += "处理模型数: " + processedCount as string + "\r\n"
                        if result[2] > 0 then (
                            logMessage += "错误数量: " + result[2] as string + "\r\n"
                            logMessage += "错误信息: " + result[3] + "\r\n"
                        )
                        logMessage += "起始序号: " + startNumber as string + "\r\n"
                        logMessage += "填充位数: " + fillWidth as string + "\r\n"
                        logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                        logMessage += "------------------------ \r\n"
                        
                        insertLog logMessage
                    )
                    else (
                        if not chkAllowEmpty.checked then (
                            messageBox "请填写所有模型命名相关的字段！" title:"提示"
                        ) else (
                            messageBox "请至少填写一个模型命名相关的字段！" title:"提示"
                        )
                        return undefined
                    )
                )
                
                -- 贴图重命名功能
                if chk_enableTextureRename.checked then (
                    -- 检查必填字段
                    local fieldsValid = true
                    
                    if not chkAllowEmpty.checked then (
                        -- 如果不允许空输入框，检查所有字段是否都已填写
                        if base2.text == "" or city2.text == "" or proj2.text == "" or abbr2.text == "" then (
                            fieldsValid = false
                        )
                    ) else (
                        -- 如果允许空输入框，检查是否至少有一个字段填写了值
                        if base2.text == "" and city2.text == "" and proj2.text == "" and abbr2.text == "" then (
                            fieldsValid = false
                        )
                    )
                    
                    if fieldsValid then (
                        try (
                            hasValidOperation = true
                            local startTime = timestamp()
                            local processedCount = 0
                            local skippedCount = 0
                            
                            -- 获取输入值并确保它们都有效
                            local baseCode = if base2.text != "" then base2.text else ""
                            local cityName = if city2.text != "" then city2.text else ""
                            local projName = if proj2.text != "" then proj2.text else ""
                            local abbrName = if abbr2.text != "" then abbr2.text else ""
                            local startNumber = try(start2.value as integer)catch(1)
                            local fillWidth = try(fillNum2.value as integer)catch(3)
                            
                            -- 获取要处理的对象数组
                            local objsToProcess = #()
                            if rad2.state == 1 then (
                                objsToProcess = selection as array
                                if objsToProcess.count == 0 then (
                                    messageBox "请先选择要处理的对象！" title:"提示"
                                    return undefined
                                )
                            ) else (
                                for obj in geometry where not obj.isHidden do (
                                    append objsToProcess obj
                                )
                            )
                            
                            -- 确保所需函数已定义
                            if not iskindof ::formatNumberWithLeadingZeros #function then (
                                -- 内联定义formatNumberWithLeadingZeros函数
                                global formatNumberWithLeadingZeros
                                fn formatNumberWithLeadingZeros num width = (
                                    -- 确保输入值有效
                                    if num == undefined do num = 1
                                    if width == undefined do width = 3
                                    
                                    -- 转换为字符串并填充
                                    local numStr = num as string
                                    while numStr.count < width do (
                                        numStr = "0" + numStr
                                    )
                                    numStr
                                )
                            )
                            
                            -- 收集贴图信息（不依赖collectAllTexturePaths函数）
                            local textureInfo = #()
                            local pathToIndex = #()
                            
                            -- 临时函数来收集贴图路径
                            fn collectTextures objsToProcess = (
                                local result = #()
                                local paths = #()
                                
                                for obj in objsToProcess where obj != undefined and obj.material != undefined do (
                                    if classof obj.material == MultiMaterial then (
                                        for i = 1 to obj.material.numsubs do (
                                            local subMat = obj.material[i]
                                            if subMat != undefined then (
                                                local diffuseMap = case classof subMat of (
                                                    StandardMaterial: subMat.diffuseMap
                                                    VRayMtl: subMat.texmap_diffuse
                                                    PhysicalMaterial: subMat.base_color_map
                                                    default: undefined
                                                )
                                                
                                                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                                    local path = diffuseMap.filename
                                                    local index = findItem paths path
                                                    if index == 0 then (
                                                        append result #(path, #(#(obj, subMat)))
                                                        append paths path
                                                    ) else (
                                                        append result[index][2] #(obj, subMat)
                                                    )
                                                )
                                            )
                                        )
                                    ) else (
                                        local diffuseMap = case classof obj.material of (
                                            StandardMaterial: obj.material.diffuseMap
                                            VRayMtl: obj.material.texmap_diffuse
                                            PhysicalMaterial: obj.material.base_color_map
                                            default: undefined
                                        )
                                        
                                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                            local path = diffuseMap.filename
                                            local index = findItem paths path
                                            if index == 0 then (
                                                append result #(path, #(#(obj, obj.material)))
                                                append paths path
                                            ) else (
                                                append result[index][2] #(obj, obj.material)
                                            )
                                        )
                                    )
                                )
                                result
                            )
                            
                            -- 收集贴图信息
                            textureInfo = collectTextures objsToProcess
                            local currentNumber = startNumber
                            local renameMappings = #()
                            
                            -- 生成重命名映射
                            for info in textureInfo do (
                                local oldPath = info[1]
                                
                                -- 检查贴图是否在排除列表中
                                if findItem excludedTextures oldPath > 0 then (
                                    skippedCount += 1
                                    continue -- 跳过此贴图
                                )
                                
                                if doesFileExist oldPath then (
                                    -- 生成新的贴图名称
                                    local fileDir = getFilenamePath oldPath
                                    local fileExt = getFilenameType oldPath
                                    local numStr = formatNumberWithLeadingZeros currentNumber fillWidth
                                    
                                    -- 使用数组收集非空部分，然后用下划线连接
                                    local nameParts = #()
                                    if baseCode != "" then append nameParts baseCode
                                    if cityName != "" then append nameParts cityName
                                    if projName != "" then append nameParts projName
                                    if abbrName != "" then append nameParts abbrName
                                    append nameParts numStr
                                    
                                    -- 用下划线连接所有部分
                                    local newFileName = nameParts[1]
                                    for i = 2 to nameParts.count do (
                                        newFileName += "_" + nameParts[i]
                                    )
                                    
                                    local newPath = fileDir + newFileName + fileExt
                                    
                                    append renameMappings #(oldPath, newPath, info[2])
                                    currentNumber += 1
                                )
                            )
                            
                            -- 执行重命名操作
                            for mapping in renameMappings do (
                                try (
                                    local oldPath = mapping[1]
                                    local newPath = mapping[2]
                                    local affectedMaterials = mapping[3]
                                    
                                    -- 重命名文件
                                    if doesFileExist oldPath then (
                                        if (renameFile oldPath newPath) then (
                                            -- 尝试注册重命名历史
                                            try(registerTextureRename oldPath newPath)catch()
                                            
                                            -- 更新材质路径
                                            for matInfo in affectedMaterials do (
                                                local obj = matInfo[1]
                                                local mat = matInfo[2]
                                                
                                                local diffuseMap = case classof mat of (
                                                    StandardMaterial: mat.diffuseMap
                                                    VRayMtl: mat.texmap_diffuse
                                                    PhysicalMaterial: mat.base_color_map
                                                    default: undefined
                                                )
                                                
                                                if diffuseMap != undefined then (
                                                    diffuseMap.filename = newPath
                                                )
                                            )
                                            
                                            -- 更新场景中所有使用该贴图的材质
                                            for mat in scenematerials do (
                                                -- 检查单一材质
                                                if classof mat != MultiMaterial then (
                                                    local diffuseMap = case classof mat of (
                                                        StandardMaterial: mat.diffuseMap
                                                        VRayMtl: mat.texmap_diffuse
                                                        PhysicalMaterial: mat.base_color_map
                                                        default: undefined
                                                    )
                                                    
                                                    if diffuseMap != undefined and diffuseMap.filename == oldPath then (
                                                        diffuseMap.filename = newPath
                                                    )
                                                )
                                                -- 检查多重材质
                                                else if classof mat == MultiMaterial then (
                                                    for i = 1 to mat.numsubs do (
                                                        local subMat = mat[i]
                                                        if subMat != undefined then (
                                                            local diffuseMap = case classof subMat of (
                                                                StandardMaterial: subMat.diffuseMap
                                                                VRayMtl: subMat.texmap_diffuse
                                                                PhysicalMaterial: subMat.base_color_map
                                                                default: undefined
                                                            )
                                                            
                                                            if diffuseMap != undefined and diffuseMap.filename == oldPath then (
                                                                diffuseMap.filename = newPath
                                                            )
                                                        )
                                                    )
                                                )
                                            )
                                            
                                            processedCount += 1
                                        ) else (
                                            format "重命名文件失败: % -> %\n" oldPath newPath
                                        )
                                    )
                                ) catch (
                                    format "重命名文件时出错: %\n" (getCurrentException())
                                    continue
                                )
                            )
                        ) catch (
                            messageBox ("重命名过程中发生错误：" + (getCurrentException())) title:"错误"
                        )
                        
                        local endTime = timestamp()
                        local elapsedTime = (endTime - startTime) / 1000.0
                        
                        -- 生成日志信息
                        local logMessage = "------------------------ \r\n"
                        logMessage += "贴图重命名完成\r\n"
                        logMessage += "处理贴图数: " + processedCount as string + "\r\n"
                        if skippedCount > 0 then logMessage += "跳过贴图数(已排除): " + skippedCount as string + "\r\n"
                        logMessage += "起始序号: " + startNumber as string + "\r\n"
                        logMessage += "填充位数: " + fillWidth as string + "\r\n"
                        logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                        logMessage += "------------------------ \r\n"
                        
                        insertLog logMessage
                    )
                    else (
                        if not chkAllowEmpty.checked then (
                            messageBox "请填写所有贴图命名相关的字段！" title:"提示"
                        ) else (
                            messageBox "请至少填写一个贴图命名相关的字段！" title:"提示"
                        )
                        return undefined
                    )
                )
                
                -- 贴图归档功能
                if chkArchive.checked then (
                    hasValidOperation = true
                    local startTime = timestamp()
                    
                    -- 获取要处理的对象数组
                    local objsToProcess = #()
                    -- 如果已经启用了其他重命名功能，使用对应的选择模式
                    if chk_enableRename.checked and rad1.state == 1 then (
                        objsToProcess = selection as array
                    ) else if chk_enableTextureRename.checked and rad2.state == 1 then (
                        objsToProcess = selection as array
                    ) else (
                        -- 否则使用贴图重命名的选择模式
                        if rad2.state == 1 then (
                            objsToProcess = selection as array
                            if objsToProcess.count == 0 then (
                                messageBox "请先选择要处理的对象！" title:"提示"
                                return undefined
                            )
                        ) else (
                            for obj in geometry where not obj.isHidden do (
                                append objsToProcess obj
                            )
                        )
                    )
                    
                    -- 执行贴图归档
                    local result = archiveMapFiles objsToProcess
                    local processedCount = result.count
                    
                    local endTime = timestamp()
                    local elapsedTime = (endTime - startTime) / 1000.0
                    
                    -- 生成日志信息
                    local logMessage = "------------------------ \r\n"
                    logMessage += "贴图归档完成\r\n"
                    logMessage += "处理贴图数: " + processedCount as string + "\r\n"
                    logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                    logMessage += "------------------------ \r\n"
                    
                    insertLog logMessage
                )
                
                -- 如果三个功能都未启用，显示提示
                if not hasValidOperation then (
                    messageBox "至少启用一个功能！" title:"提示"
                    return undefined
                )
                
                -- 成功执行后关闭窗口
                if hasValidOperation then (
                    local timer = createCloseTimer()
                    if timer != undefined then (
                        timer.Start()
                    ) else (
                        try(destroyDialog renameRollout)catch()
                    )
                )
            )
            catch (
                messageBox ("重命名过程中发生错误：" + (getCurrentException())) title:"错误"
            )
        )

        -- 使用贴图名称按钮事件
        on useTextureBtn pressed do (
            try (
                local startTime = timestamp()
                local processedCount = 0
                local errorCount = 0
                local emptyMatCount = 0
                
                -- 获取当前选中的对象
                local selObjects = selection as array
                if selObjects.count == 0 then (
                    messageBox "请先选择要处理的模型！" title:"提示"
                    return undefined
                )
                
                -- 清空主窗口的列表
                if replaceMissingMapsRollout.lvModels != undefined do (
                    replaceMissingMapsRollout.lvModels.Items.Clear()
                )
                
                for item in selObjects do (
                    if item.material != undefined then (
                        if (classof item.material == Multimaterial) then (
                            try (
                                local hasEmptyMat = false
                                -- 检查多重材质中是否有空材质
                                for i = 1 to item.material.numsubs do (
                                    if item.material[i] == undefined then (
                                        -- 添加到列表中
                                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" item.name
                                        listItem.SubItems.Add "多重材质"
                                        listItem.SubItems.Add (i as string)
                                        listItem.SubItems.Add ""
                                        listItem.SubItems.Add "材质ID " + i as string + " 为空"
                                        listItem.ForeColor = (dotNetClass "System.Drawing.Color").Red
                                        replaceMissingMapsRollout.lvModels.Items.Add listItem
                                        
                                        hasEmptyMat = true
                                        emptyMatCount += 1
                                    )
                                )
                                
                                -- 如果没有材质，则进行命名
                                if not hasEmptyMat then (
                                    -- 优化材质
                                    optimaizeMat item
                                    if(_setMaterialName item.material) then (
                                        item.material.name = "MAT_" + substring item.name 4 item.name.count
                                        processedCount += 1
                                    )
                                    else (
                                        errorCount += 1
                                    )
                                )
                            ) catch (
                                errorCount += 1
                                format "Error processing multimaterial: %\n" (getCurrentException())
                            )
                        )
                        else (
                            if(_setMaterialName item.material) then (
                                processedCount += 1
                            )
                            else (
                                errorCount += 1
                            )
                        )
                    )
                    else (
                        -- 添加无材质的物体到列表
                        local listItem = dotNetObject "System.Windows.Forms.ListViewItem" item.name
                        listItem.SubItems.Add "无材质"
                        listItem.SubItems.Add "0"
                        listItem.SubItems.Add ""
                        listItem.SubItems.Add "物体无材质"
                        listItem.ForeColor = (dotNetClass "System.Drawing.Color").Red
                        replaceMissingMapsRollout.lvModels.Items.Add listItem
                        emptyMatCount += 1
                    )
                )
                
                try(displayMat()) catch()
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = "------------------------ \r\n"
                logMessage += "材质命名完成\r\n"
                logMessage += "成功处理材质数: " + processedCount as string + "\r\n"
                if errorCount > 0 then (
                    logMessage += "处理失败数: " + errorCount as string + "\r\n"
                )
                if emptyMatCount > 0 then (
                    logMessage += "空材质/无材质数: " + emptyMatCount as string + "\r\n"
                )
                logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
                logMessage += "------------------------ \r\n"
                
                -- 更新日志
                insertLog logMessage
                
                -- 使用计时器关闭窗口
                try(
                    local timer = createCloseTimer()
                    timer.Start()
                )catch(
                    try(destroyDialog renameRollout)catch()
                )
            )
            catch (
                messageBox ("处理材质命名时发生错误：" + (getCurrentException())) title:"错误"
            )
        )

        -- 在 renameRollout 中添加关闭事件处理
        on renameRollout close do (
            try (
                -- 清理计时器
                if closeTimer != undefined then (
                    closeTimer.Stop()
                    cleanupDotNetObject closeTimer
                    closeTimer = undefined
                )
                
                -- 清理文本框
                cleanupDotNetObject base1
                cleanupDotNetObject city1
                cleanupDotNetObject proj1
                cleanupDotNetObject abbr1
                cleanupDotNetObject base2
                cleanupDotNetObject city2
                cleanupDotNetObject proj2
                cleanupDotNetObject abbr2
                
                -- 清理贴图列表控件
                cleanupDotNetObject lbAllTextures
                cleanupDotNetObject lbExcludedTextures
                
                -- 清理其他资源
                cleanupResources()
            ) catch (
                format "清理重命名窗口资源时出错: %\n" (getCurrentException())
            )
        )
    )

    -- 添加贴图归档函数
    fn archiveMapFile sourceFile = (
        try (
            -- 获取当前场景文件路径
            local scenePath = maxFilePath
            if scenePath == "" then (
                messageBox "请先保存场景文件！" title:"提示"
                return false
            )
            
            -- 创建maps文夹
            local mapsDir = pathConfig.appendPath scenePath "maps"
            makeDir mapsDir
            
            -- 获取源文件名
            local fileName = filenameFromPath sourceFile
            
            -- 构建目标文件路径
            local targetFile = pathConfig.appendPath mapsDir fileName
            
            -- 复制文件
            if doesFileExist sourceFile then (
                copyFile sourceFile targetFile
                return true
            )
            return false
        ) catch (
            format "归档贴图出错: %\n" (getCurrentException())
            return false
        )
    )

    -- 修改主界面中重命名按钮的事件处理程序
    on btnRename pressed do (
        try (
            -- 创建非模态对话框
            createDialog renameRollout modal:false
        )
        catch (
            messageBox ("创建重命名窗口时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    on btnCheckModelID pressed do (
        if g_resourceManager.getIsProcessing() do return()
        g_resourceManager.setIsProcessing true
        disableButton btnCheckModelID
        try (
            local startTime = timestamp()
            
            -- 清空列表并暂停更新
            if lvModels != undefined do (
                lvModels.Items.Clear()
                lvModels.BeginUpdate()
            )
            
            if cmbIDLimit.SelectedItem != undefined then (
                local idLimit = cmbIDLimit.SelectedItem as integer
                local totalModels = 0
                local totalMaterials = 0
                local abnormalModels = 0
                local overLimitModels = 0
                
                -- 创建临时数组存储列表项
                local items = #()
                
                -- 遍历几何体
                for obj in geometry do (
                    totalModels += 1
                    local materialCount = 0
                    local faceCount = 0
                    local errorMsg = ""
                    
                    -- 获取面数
                    if isKindOf obj Editable_Poly then
                        faceCount = polyOp.getNumFaces obj
                    else if isKindOf obj Editable_Mesh then
                        faceCount = obj.numFaces
                        
                    -- 检查材质
                    if obj.material != undefined then (
                        if classof obj.material == MultiMaterial then (
                            materialCount = obj.material.numsubs
                            if materialCount > idLimit then (
                                errorMsg = "超出ID限制"
                                overLimitModels += 1
                            )
                            else if materialCount > faceCount then
                                errorMsg = "材质ID数量过多"
                            else if materialCount < faceCount then
                                errorMsg = "材ID数量未超过"
                        )
                        else
                            materialCount = 1
                        
                        totalMaterials += materialCount
                    )
                    else (
                        materialCount = 0
                        errorMsg = "无材质"
                    )
                    
                    if errorMsg != "" then
                        abnormalModels += 1
                    
                    -- 创建列表项
                    local item = dotNetObject "System.Windows.Forms.ListViewItem" obj.name
                    item.SubItems.Add (if obj.material != undefined then obj.material.name else "无材质")
                    item.SubItems.Add (materialCount as string)
                    item.SubItems.Add ""
                    item.SubItems.Add errorMsg
                    
                    if materialCount > idLimit then
                        item.ForeColor = (dotNetClass "System.Drawing.Color").Red
                    else
                        item.ForeColor = (dotNetClass "System.Drawing.Color").Black
                    
                    append items item
                )
                
                -- 批量添加列表项
                local itemsArray = dotNetObject "System.Windows.Forms.ListViewItem[]" items.count
                for i = 1 to items.count do (
                    itemsArray[i-1] = items[i]
                )
                lvModels.Items.AddRange itemsArray
                
                -- 恢复ListView更新
                lvModels.EndUpdate()
                
                local endTime = timestamp()
                local elapsedTime = (endTime - startTime) / 1000.0
                
                -- 生成日志信息
                local logMessage = stringStream ""
                format "------------------------ \r\n" to:logMessage
                format "模型ID检查完成\r\n" to:logMessage
                format "总模型数量: %个\r\n总材质ID数: %个\r\n" totalModels totalMaterials to:logMessage
                format "异常模型数: %个\r\n超出限制模型数: %个\r\n" abnormalModels overLimitModels to:logMessage
                format "ID限制: %个\r\n" idLimit to:logMessage
                format "耗时: % 秒\r\n" elapsedTime to:logMessage
                format "------------------------ \r\n" to:logMessage
                
                insertLog (logMessage as string)
                
                -- 清理资源
                free logMessage
                items = undefined
                gc light:true
            )
            else (
                messageBox "请先选择ID限制值！" title:"提示"
            )
        ) catch (
            messageBox ("检查模型ID时发生错误：" + (getCurrentException())) title:"错误"
        )
        g_resourceManager.setIsProcessing false
        enableButton btnCheckModelID
    )

    -- 初始化
    fn initializeUI = (
        try (
            -- 初始化ListView
            if not initializeListView lvModels then (
                throw "ListView初始化失败"
            )
            
            -- 初始化日志文本框
            if edtLog != undefined then (
                edtLog.Multiline = true
                edtLog.ReadOnly = true
                edtLog.BackColor = (dotNetClass "System.Drawing.Color").LightGray
                edtLog.Font = dotNetObject "System.Drawing.Font" "Arial" 9
                edtLog.WordWrap = true
                edtLog.ScrollBars = edtLog.ScrollBars.Vertical
            )
            
            -- 初始化模型信息文本框
            if edtModelInfo != undefined then (
                edtModelInfo.Multiline = true
                edtModelInfo.ReadOnly = true
                edtModelInfo.TextAlign = edtModelInfo.TextAlign.Left
                edtModelInfo.BackColor = (dotNetClass "System.Drawing.Color").LightGray
                edtModelInfo.BorderStyle = edtModelInfo.BorderStyle.None
            )
            
            -- 初始化ID限制下拉框
            if cmbIDLimit != undefined then (
                cmbIDLimit.Items.Clear()
                local idLimits = #(4, 8, 12, 20)
                for limit in idLimits do (
                    cmbIDLimit.Items.Add (limit as string)
                )
                cmbIDLimit.SelectedIndex = 2
                cmbIDLimit.DropDownStyle = cmbIDLimit.DropDownStyle.DropDownList
            )
            
            return true
        ) catch (
            messageBox ("初始化UI失败: " + (getCurrentException())) title:"错误"
            return false
        )
    )

    -- 打开事件处理
    on replaceMissingMapsRollout open do (
        try (
            -- 初始化UI控件
            initListView()
            initModelInfoTextBox()
            initLogTextBox()
            initIDLimitComboBox()
            
            -- 初始化折叠区域为隐藏状态
            isCollapsibleVisible = false
            
            -- 确保所有控件已初始化后再设置可见性
            if grpCollapsible != undefined then grpCollapsible.visible = false
            if btnAdvanced1 != undefined then btnAdvanced1.visible = false
            if btnCheckUpdate != undefined then btnCheckUpdate.visible = false
            if chkEnableMemoryMonitor != undefined then chkEnableMemoryMonitor.visible = false
            
            -- 初始化内存统计面板为隐藏状态
            if grpMemoryPanel != undefined then grpMemoryPanel.visible = false
            if lvMemoryStats != undefined then lvMemoryStats.visible = false
            
            -- 记录日志
            insertLog "工具已启动，准备就绪。" clearPrevious:true
            
                            -- 启动内存监控(如果已勾选)
                if chkEnableMemoryMonitor != undefined and chkEnableMemoryMonitor.checked do (
                    -- 启动内存监控
                    g_memoryMonitor.startMonitoring()
                    insertLog "内存监控已启动，将自动管理资源。"
                    
                    -- 显示右侧内存统计面板
                    if grpMemoryPanel != undefined then grpMemoryPanel.visible = true
                    if lvMemoryStats != undefined then (
                        lvMemoryStats.visible = true
                        
                        -- 初始化内存统计表格
                        initMemoryStatsListView()
                        
                        -- 立即更新一次统计数据
                        updateMemoryStats()
                        
                        -- 启动定时更新
                        startMemoryStatsTimer()
                        
                        -- 输出调试日志
                        format "内存统计面板初始化完成\n"
                    )
                    
                    -- 调整主窗口宽度以适应内存统计面板
                    replaceMissingMapsRollout.width = 900
                )
        ) catch (
            messageBox ("初始化界面时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    -- 内存监控复选框事件
    on chkEnableMemoryMonitor changed state do (
        try (
            if state then (
                -- 启动内存监控
                g_memoryMonitor.startMonitoring()
                insertLog "内存监控已启动，将自动管理资源。"
                
                -- 显示右侧内存统计面板
                if grpMemoryPanel != undefined then grpMemoryPanel.visible = true else format "统计面板未找到\n"
                
                -- 调整主窗口宽度以适应内存统计面板
                try (replaceMissingMapsRollout.width = 900) catch (format "调整窗口宽度出错\n")
                
                -- 确保表格控件可用
                if lvMemoryStats != undefined then (
                    format "找到内存统计表格控件\n"
                    lvMemoryStats.visible = true
                    
                    -- 初始化内存统计表格
                    if not initMemoryStatsListView() then (
                        format "表格初始化失败，尝试手动初始化\n"
                        -- 手动设置基本属性
                        try (
                            lvMemoryStats.View = (dotNetClass "System.Windows.Forms.View").Details
                            lvMemoryStats.GridLines = true
                            lvMemoryStats.FullRowSelect = true
                            
                            -- 清除现有列并添加新列
                            lvMemoryStats.Columns.Clear()
                            lvMemoryStats.Columns.Add "统计项目" 130
                            lvMemoryStats.Columns.Add "数值" 90
                            
                            -- 添加测试项
                            local item = dotNetObject "System.Windows.Forms.ListViewItem" "手动初始化"
                            item.SubItems.Add "成功"
                            lvMemoryStats.Items.Add item
                            
                            g_resourceManager.registerDotNetObject lvMemoryStats
                        ) catch (
                            format "手动初始化表格失败: %\n" (getCurrentException())
                        )
                    )
                    
                    -- 立即更新一次统计
                    if not updateMemoryStats() then (
                        format "更新统计数据失败，尝试添加默认数据\n"
                        try (
                            -- 添加默认数据
                            lvMemoryStats.Items.Clear()
                            local item1 = dotNetObject "System.Windows.Forms.ListViewItem" "3ds Max内存使用"
                            item1.SubItems.Add ((heapSize() / 1048576.0) as string + " MB")
                            lvMemoryStats.Items.Add item1
                            
                            local item2 = dotNetObject "System.Windows.Forms.ListViewItem" "可用内存"
                            item2.SubItems.Add ((heapFree() / 1048576.0) as string + " MB")
                            lvMemoryStats.Items.Add item2
                        ) catch (
                            format "添加默认数据失败: %\n" (getCurrentException())
                        )
                    )
                    
                    -- 启动定时更新
                    startMemoryStatsTimer interval:5000
                    
                ) else (
                    format "内存统计表格控件未找到，尝试创建\n"
                    try (
                        -- 尝试重新创建ListView控件
                        lvMemoryStats = dotNetObject "System.Windows.Forms.ListView"
                        lvMemoryStats.Bounds = dotNetObject "System.Drawing.Rectangle" 650 30 230 350
                        lvMemoryStats.View = (dotNetClass "System.Windows.Forms.View").Details
                        lvMemoryStats.GridLines = true
                        
                        -- 添加列
                        lvMemoryStats.Columns.Add "统计项目" 130
                        lvMemoryStats.Columns.Add "数值" 90
                        
                        -- 添加一个测试项
                        local item = dotNetObject "System.Windows.Forms.ListViewItem" "新建控件测试"
                        item.SubItems.Add "成功"
                        lvMemoryStats.Items.Add item
                        
                        -- 添加到窗体
                        replaceMissingMapsRollout.Controls.Add lvMemoryStats
                        lvMemoryStats.visible = true
                        
                        -- 注册到资源管理器
                        g_resourceManager.registerDotNetObject lvMemoryStats
                    ) catch (
                        format "创建内存统计表格失败: %\n" (getCurrentException())
                        insertLog "内存统计表格创建失败，但内存监控仍会正常工作。"
                    )
                )
            ) else (
                -- 停止内存监控
                g_memoryMonitor.stopMonitoring()
                insertLog "内存监控已停止。"
                
                -- 停止定时更新
                stopMemoryStatsTimer()
                
                -- 隐藏右侧内存统计面板
                if grpMemoryPanel != undefined then grpMemoryPanel.visible = false
                if lvMemoryStats != undefined then lvMemoryStats.visible = false
                
                -- 恢复主窗口宽度
                replaceMissingMapsRollout.width = 640
            )
        ) catch (
            messageBox ("切换内存监控时发生错误：" + (getCurrentException())) title:"错误"
        )
    )

    -- 添加窗口关闭事件处理
    on replaceMissingMapsRollout close do (
        try (
            -- 停止内存监控
            if g_memoryMonitor != undefined do (
                g_memoryMonitor.stopMonitoring()
            )
            
            -- 停止内存统计更新定时器
            stopMemoryStatsTimer()
            
            -- 清理ListView
            cleanupListView lvModels
            
            -- 清理内存统计表格
            if lvMemoryStats != undefined do (
                lvMemoryStats.Items.Clear()
                g_resourceManager.unregisterDotNetObject lvMemoryStats
                cleanupDotNetObject lvMemoryStats
            )
            
            -- 清理文本框
            cleanupDotNetObject edtLog
            cleanupDotNetObject edtModelInfo
            
            -- 清理下拉框
            cleanupDotNetObject cmbIDLimit
            
            -- 清理全局资源
            enhancedCleanupResources()
            
        ) catch (
            format "清理主窗资源时出错: %\n" (getCurrentException())
        )
    )

    -- 添加更新按钮（移动到高级选项区域内）
    -- 此按钮已在前面定义，不需要重复声明
    
    -- 添加更新按钮的事件处理
    on btnCheckUpdate pressed do (
        try (
            -- 记录日志
            insertLog "正在检查更新..." clearPrevious:true
            
            -- 当前版本号
            local currentVersion = "1.3.4"
            
            local apiUrl = "https://api.github.com/repos/Rkesent/3DMAX_Integrated-plugins/releases/latest"
            
            local httpRequest = dotNetObject "System.Net.WebClient"
            httpRequest.Headers.Add "User-Agent" "3DMAX-Plugin-Updater"
            
            try (
                -- 获取API响应
                local response = httpRequest.DownloadString apiUrl
                
                -- 使用简单的字符串操作提取版本号和下载URL
                local versionRegex = "\"tag_name\":\"(.*?)\""
                local versionMatch = (dotNetClass "System.Text.RegularExpressions.Regex").Match response versionRegex
                
                local downloadRegex = "\"browser_download_url\":\"(.*?)\""
                local downloadMatch = (dotNetClass "System.Text.RegularExpressions.Regex").Match response downloadRegex
                
                if versionMatch.Success and downloadMatch.Success then (
                    -- 提取版本号并移除v前缀
                    local latestVersion = versionMatch.Groups.Item[1].Value
                    latestVersion = substituteString latestVersion "v" ""
                    
                    -- 提取下载URL
                    local downloadUrl = downloadMatch.Groups.Item[1].Value
                    
                    -- 简单字符串比较
                    if currentVersion != latestVersion then (
                        local updateMessage = "发现新版本: v" + latestVersion + "\n当前版本: v" + currentVersion + "\n\n是否现在更新?"
                        if queryBox updateMessage title:"插件更新" beep:true then (
                            -- 获取当前脚本的路径
                            local currentScriptPath = getFilenamePath (getThisScriptFilename())
                            -- 使用新的文件命名格式，保存到当前脚本所在的目录
                            local downloadPath = currentScriptPath + "Post-processing.Toolkit-v" + latestVersion + ".ms"
                            
                            -- 下载文件
                            httpRequest.DownloadFile downloadUrl downloadPath
                            
                            -- 获取当前脚本的完整路径，用于后续可能的删除操作
                            local currentScriptFullPath = getThisScriptFilename()
                            
                            -- 提示更新完成，并询问是否删除当前版本
                            local deleteMessage = "新版本已下载至:\n" + downloadPath + "\n\n是否删除当前使用的脚本版本?"
                            if queryBox deleteMessage title:"更新完成" beep:false then (
                                -- 创建一个VBS脚本来删除当前脚本文件
                                local vbsFilePath = (getFilenamePath currentScriptFullPath) + "delete_script.vbs"
                                local vbsFile = createFile vbsFilePath
                                
                                -- 添加VBS脚本内容
                                format "Option Explicit\r\n" to:vbsFile
                                format "Dim FSO, targetFile, WshShell\r\n" to:vbsFile
                                format "Set WshShell = CreateObject(\"WScript.Shell\")\r\n" to:vbsFile
                                format "WScript.Sleep 5000 ' 等待5秒\r\n" to:vbsFile
                                
                                -- 添加删除文件的代码
                                format "Set FSO = CreateObject(\"Scripting.FileSystemObject\")\r\n" to:vbsFile
                                format "If FSO.FileExists(\"%\") Then\r\n" currentScriptFullPath to:vbsFile
                                format "    On Error Resume Next\r\n" to:vbsFile
                                format "    FSO.DeleteFile \"%\", True\r\n" currentScriptFullPath to:vbsFile
                                format "    If Err.Number <> 0 Then\r\n" to:vbsFile
                                format "        WshShell.Popup \"无法删除文件: \" & Err.Description, 5, \"删除失败\", 16\r\n" to:vbsFile
                                format "    Else\r\n" to:vbsFile
                                format "        WshShell.Popup \"旧版本脚本已成功删除！\", 5, \"删除成功\", 64\r\n" to:vbsFile
                                format "    End If\r\n" to:vbsFile
                                format "End If\r\n" to:vbsFile
                                
                                -- 添加自删除代码
                                format "On Error Resume Next\r\n" to:vbsFile
                                format "FSO.DeleteFile WScript.ScriptFullName, True\r\n" to:vbsFile
                                format "Set FSO = Nothing\r\n" to:vbsFile
                                format "Set WshShell = Nothing\r\n" to:vbsFile
                                close vbsFile
                                
                                -- 运行VBS脚本
                                shellLaunch vbsFilePath ""
                                
                                messageBox "当前脚本将在5秒后自动删除，请使用新版本脚本。" title:"删除提示"
                            ) else (
                                messageBox "新版本已下载完成，请使用新版本脚本。" title:"更新完成"
                            )
                            
                            -- 关闭当前工具界面
                            try(destroyDialog replaceMissingMapsRollout)catch()
                        )
                    ) else (
                        messageBox ("您已经使用的是最新版本: v" + currentVersion) title:"检查更新" beep:false
                    )
                ) else (
                    throw "无法解析GitHub API响应"
                )
            ) catch (
                local errorMsg = "检查更新失败：" + (getCurrentException()) + "\n\n请访问 https://github.com/Rkesent/3DMAX_Integrated-plugins 手动检查更新。"
                messageBox errorMsg title:"更新错误"
                insertLog errorMsg
            )
            
            -- 清理资源
            try(httpRequest.Dispose())catch()
            
        ) catch (
            local errorMsg = "检查更新时出错：" + (getCurrentException()) + "\n\n请访问 https://github.com/Rkesent/3DMAX_Integrated-plugins 手动检查更新。"
            messageBox errorMsg title:"更新错误"
            insertLog errorMsg
        )
    )

    -- 修复贴图尺寸按钮事件
    on btnFixTextures pressed do (
        try (
            local startTime = timestamp()
            local processedFiles = #() -- 用于记录已处理的文件
            local fixedCount = 0
            local errorCount = 0
            
            -- 获取列表中的项目
            local itemsToProcess = for i = 0 to lvModels.Items.Count - 1 collect lvModels.Items.Item[i]
            
            with redraw off (
                for item in itemsToProcess do (
                    local objName = item.Text
                    local matName = item.SubItems.Item[1].Text
                    local fileName = try(item.SubItems.Item[3].Text)catch("")
                    
                    -- 获取对象
                    local obj = getNodeByName objName
                    if obj != undefined and obj.material != undefined then (
                        -- 获取贴图路径
                        local texturePath = undefined
                        if classof obj.material == MultiMaterial then (
                            local matID = try(item.SubItems.Item[2].Text as integer)catch(1)
                            if matID > 0 and matID <= obj.material.numsubs then (
                                local subMat = obj.material[matID]
                                if subMat != undefined then (
                                    texturePath = case classof subMat of (
                                        StandardMaterial: if subMat.diffuseMap != undefined then subMat.diffuseMap.filename else undefined
                                        VRayMtl: if subMat.texmap_diffuse != undefined then subMat.texmap_diffuse.filename else undefined
                                        PhysicalMaterial: if subMat.base_color_map != undefined then subMat.base_color_map.filename else undefined
                                        default: undefined
                                    )
                                )
                            )
                        ) else (
                            texturePath = case classof obj.material of (
                                StandardMaterial: if obj.material.diffuseMap != undefined then obj.material.diffuseMap.filename else undefined
                                VRayMtl: if obj.material.texmap_diffuse != undefined then obj.material.texmap_diffuse.filename else undefined
                                PhysicalMaterial: if obj.material.base_color_map != undefined then obj.material.base_color_map.filename else undefined
                                default: undefined
                            )
                        )
                        
                        -- 如果找到贴图路径且文件存在
                        if texturePath != undefined and doesFileExist texturePath then (
                            -- 检查是否已处理过该文件
                            if findItem processedFiles texturePath == 0 then (
                                append processedFiles texturePath
                                local result = fixTextureSize texturePath
                                if result[1] then (
                                    fixedCount += 1
                                    item.SubItems.Item[4].Text = result[2]
                                ) else (
                                    errorCount += 1
                                    item.SubItems.Item[4].Text = "修复失败: " + result[2]
                                )
                            )
                        )
                    )
                )
            )
            
            local endTime = timestamp()
            local elapsedTime = (endTime - startTime) / 1000.0
            
            -- 生成日志信息
            local logMessage = "------------------------ \r\n"
            logMessage += "贴图修复完成\r\n"
            logMessage += "成功修复: " + fixedCount as string + "张\r\n"
            if errorCount > 0 then (
                logMessage += "修复失败: " + errorCount as string + "张\r\n"
            )
            logMessage += "耗时: " + elapsedTime as string + " 秒\r\n"
            logMessage += "------------------------ \r\n"
            
            insertLog logMessage clearPrevious:true
            
            -- 移除已修复的项
            if fixedCount > 0 then (
                local i = 0
                while i < lvModels.Items.Count do (
                    local item = lvModels.Items.Item[i]
                    local errorText = try(item.SubItems.Item[4].Text as string)catch("")
                    -- 使用 matchPattern 进行字符串匹配
                    if matchPattern errorText pattern:"非2次幂*" then (
                        -- 移除该项
                        lvModels.Items.RemoveAt i
                    ) else (
                        i += 1
                    )
                )
            )
            
        ) catch (
            messageBox ("修复贴图时发生错误：" + (getCurrentException())) title:"错误"
        )
    )
)

-- 添加初始化检查函数
fn initializeScript = (
    try (
        -- 检查必要的函数是否已定义
        if isPowerOfTwo == undefined or checkTextureSize == undefined then (
            throw "必要的函数未定义"
        )
        
        -- 初始化全局变量
        global missingMaps = #()
        global isProcessing = false
        
        -- 定义注册贴图重命名记录的全局函数
        global registerTextureRename
        fn registerTextureRename oldPath newPath = (
            -- 如果安装了Python，则尝试记录重命名历史
            if python != undefined then (
                try (
                    -- 确保Python脚本目录在路径中
                    local scriptPath = getDir #scripts
                    python.Execute ("import sys; sys.path.append('" + scriptPath + "')")
                    
                    -- 尝试导入模块并记录重命名
                    python.Execute ("try:\n    import TextureRenameHistory as trh\n    manager = trh.TextureRenameHistoryManager()\n    manager.add_record('" + oldPath + "', '" + newPath + "')\nexcept Exception as e:\n    print('记录贴图重命名历史出错:', e)")
                ) catch (
                    format "记录贴图重命名历史出错: %\n" (getCurrentException())
                )
            )
        )
        
        -- 返回成功
        return true
    ) catch (
        messageBox ("脚本初始化失败：" + (getCurrentException())) title:"错误"
        return false
    )
)

-- 主程序入口
if initializeScript() then (
    try (
        -- 使用默认高度创建对话框
        createDialog replaceMissingMapsRollout width:640 height:420
    ) catch (
        messageBox ("创建界面时发生错误：" + (getCurrentException())) title:"错误"
        try(cleanupResources())catch()
    )
)

-- 在 archiveMapFile 函数后添加新的 archiveMapFiles 函数
fn archiveMapFiles objsToProcess = (
    local mapPathMapping = undefined
    
    try (
        mapPathMapping = #()
        -- 获取当前场景文件路径
        local scenePath = maxFilePath
        if scenePath == "" then (
            messageBox "请先保存场景文件！" title:"提示"
            return #()
        )
        
        -- 创建maps文件夹，如果已存在则创建maps1, maps2等
        local mapsDir = undefined
        local baseName = "maps"
        local index = 0
        local dirName = baseName
        
        while true do (
            mapsDir = pathConfig.appendPath scenePath dirName
            if not doesFileExist mapsDir then (
                makeDir mapsDir
                exit
            )
            index += 1
            dirName = baseName + index as string
        )
        
        -- 收集并复制所有贴图
        for obj in objsToProcess do (
            if obj.material != undefined then (
                if classof obj.material == MultiMaterial then (
                    for i = 1 to obj.material.numsubs do (
                        local subMat = obj.material[i]
                        if subMat != undefined then (
                            local diffuseMap = case classof subMat of (
                                StandardMaterial: subMat.diffuseMap
                                VRayMtl: subMat.texmap_diffuse
                                PhysicalMaterial: subMat.base_color_map
                                default: undefined
                            )
                            
                            if diffuseMap != undefined and diffuseMap.filename != undefined then (
                                local oldPath = diffuseMap.filename
                                if findItem (for m in mapPathMapping collect m[1]) oldPath == 0 then (
                                    -- 获取文件名
                                    local fileName = filenameFromPath oldPath
                                    -- 构建新路径
                                    local newPath = pathConfig.appendPath mapsDir fileName
                                    
                                    -- 复制文件
                                    if doesFileExist oldPath then (
                                        copyFile oldPath newPath
                                        -- 更新材质的贴图路径
                                        diffuseMap.filename = newPath
                                        append mapPathMapping #(oldPath, newPath)
                                    )
                                )
                            )
                        )
                    )
                ) else (
                    local diffuseMap = case classof obj.material of (
                        StandardMaterial: obj.material.diffuseMap
                        VRayMtl: obj.material.texmap_diffuse
                        PhysicalMaterial: obj.material.base_color_map
                        default: undefined
                    )
                    
                    if diffuseMap != undefined and diffuseMap.filename != undefined then (
                        local oldPath = diffuseMap.filename
                        if findItem (for m in mapPathMapping collect m[1]) oldPath == 0 then (
                            -- 获取文件名
                            local fileName = filenameFromPath oldPath
                            -- 构建新路径
                            local newPath = pathConfig.appendPath mapsDir fileName
                            
                            -- 复制文件
                            if doesFileExist oldPath then (
                                copyFile oldPath newPath
                                -- 更新材质的贴图路径
                                diffuseMap.filename = newPath
                                append mapPathMapping #(oldPath, newPath)
                            )
                        )
                    )
                )
            )
        )
        
        -- 清理资源
        local result = mapPathMapping
        mapPathMapping = undefined
        gc light:true
        return result
    ) catch (
        format "归档贴图出错: %\n" (getCurrentException())
        -- 清理资源
        if mapPathMapping != undefined do mapPathMapping = undefined
        gc light:true
        return #()
    )
)

-- 修改数字填充函数，使用更安全的方式处理数字
fn formatNumberWithLeadingZeros num width = (
    try (
        -- 确保输入值有效
        if num == undefined do num = 1
        if width == undefined do width = 3
        
        -- 转换为字符串并填充
        local numStr = num as string
        while numStr.count < width do (
            numStr = "0" + numStr
        )
        return numStr
    ) catch (
        -- 发生错误时返回默认值
        return "001"
    )
)

-- 修改重命名函数
fn processTextureRename obj startNumber fillWidth baseCode cityName projName abbrName = (
    local renameMappings = #()
    local currentNumber = startNumber
    local processedPaths = #()  -- 用于记录已处理的贴图路径
    
    try (
        if obj.material != undefined then (
            if classof obj.material == MultiMaterial then (
                -- 处理多重材质
                for i = 1 to obj.material.numsubs do (
                    local subMat = obj.material[i]
                    if subMat != undefined then (
                        -- 获取贴图
                        local diffuseMap = case classof subMat of (
                            StandardMaterial: subMat.diffuseMap
                            VRayMtl: subMat.texmap_diffuse
                            PhysicalMaterial: subMat.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                            local oldPath = diffuseMap.filename
                            -- 检查是否已经处理过这个贴图
                            if doesFileExist oldPath and findItem processedPaths oldPath == 0 then (
                                -- 生成新的贴图名称
                                local fileDir = getFilenamePath oldPath
                                local fileExt = getFilenameType oldPath
                                local numStr = formatNumberWithLeadingZeros currentNumber fillWidth
                                
                                -- 使用数组收集非空部分，然后用下划线连接
                                local nameParts = #()
                                if baseCode != "" then append nameParts baseCode
                                if cityName != "" then append nameParts cityName
                                if projName != "" then append nameParts projName
                                if abbrName != "" then append nameParts abbrName
                                append nameParts numStr
                                
                                -- 用下划线连接所有部分
                                local newFileName = nameParts[1]
                                for i = 2 to nameParts.count do (
                                    newFileName += "_" + nameParts[i]
                                )
                                
                                local newPath = fileDir + newFileName + fileExt
                                
                                -- 添加到重命名映射列表
                                append renameMappings #(oldPath, newPath)
                                append processedPaths oldPath
                                currentNumber += 1
                            )
                        )
                    )
                )
            ) else (
                -- 处理单一材质
                local diffuseMap = case classof obj.material of (
                    StandardMaterial: obj.material.diffuseMap
                    VRayMtl: obj.material.texmap_diffuse
                    PhysicalMaterial: obj.material.base_color_map
                    default: undefined
                )
                
                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                    local oldPath = diffuseMap.filename
                    -- 检查是否已经处理过这个贴图
                    if doesFileExist oldPath and findItem processedPaths oldPath == 0 then (
                        -- 生成新的贴图名称
                        local fileDir = getFilenamePath oldPath
                        local fileExt = getFilenameType oldPath
                        local numStr = formatNumberWithLeadingZeros currentNumber fillWidth
                        
                        -- 使用数组收集非空部分，然后用下划线连接
                        local nameParts = #()
                        if baseCode != "" then append nameParts baseCode
                        if cityName != "" then append nameParts cityName
                        if projName != "" then append nameParts projName
                        if abbrName != "" then append nameParts abbrName
                        append nameParts numStr
                        
                        -- 用下划线连接所有部分
                        local newFileName = nameParts[1]
                        for i = 2 to nameParts.count do (
                            newFileName += "_" + nameParts[i]
                        )
                        
                        local newPath = fileDir + newFileName + fileExt
                        
                        -- 添加到重命名映射列表
                        append renameMappings #(oldPath, newPath)
                        append processedPaths oldPath
                        currentNumber += 1
                    )
                )
            )
        )
        
        -- 返回重命名映射和当前序号
        return #(renameMappings, currentNumber)
    ) catch (
        format "处理贴图重命名时出错: %\n" (getCurrentException())
        return #(#(), startNumber)
    )
)

-- 添加检查贴图尺寸的函数
fn isPowerOfTwo n = (
    try (
        if n == undefined or n <= 0 then return false
        local i = 1
        while i <= n do (
            if i == n then return true
            i *= 2
            if i > n then return false -- 添加这个检查以避免无限循环
        )
        return false
    ) catch (
        return false
    )
)

fn checkTextureSize bmap = (
    try (
        -- 首先检查输入参数是否有效
        if bmap == undefined then return #(false, "无效贴图")
        
        -- 确保获取到有效的宽高值
        local w = undefined
        local h = undefined
        
        try (
            w = bmap.width as integer
            h = bmap.height as integer
        ) catch (
            return #(false, "无法获取贴图尺寸")
        )
        
        -- 检查是否获取到有效值
        if w == undefined or h == undefined or w <= 0 or h <= 0 then (
            return #(false, "无效尺寸")
        )
        
        -- 检查是否为2的幂次方
        local isPowerW = isPowerOfTwo w
        local isPowerH = isPowerOfTwo h
        
        if not isPowerW or not isPowerH then (
            return #(false, w as string + "x" + h as string)
        )
        
        return #(true, w as string + "x" + h as string)
    ) catch (
        return #(false, "检查失败: " + (getCurrentException()))
    )
)

-- 添加一个新的辅助函数来一次性收集所有贴图
global collectAllTexturePaths
fn collectAllTexturePaths objsToProcess = (
    local textureInfo = #()
    local pathToIndex = #()
    
    try (
        -- 遍历所有对象
        for obj in objsToProcess where obj != undefined and obj.material != undefined do (
            -- 处理多重材质
            if classof obj.material == MultiMaterial then (
                -- 处理多重材质的每个子材质
                for i = 1 to obj.material.numsubs do (
                    local subMat = obj.material[i]
                    if subMat != undefined then (
                        local diffuseMap = case classof subMat of (
                            StandardMaterial: subMat.diffuseMap
                            VRayMtl: subMat.texmap_diffuse
                            PhysicalMaterial: subMat.base_color_map
                            default: undefined
                        )
                        
                        if diffuseMap != undefined and diffuseMap.filename != undefined then (
                            local path = diffuseMap.filename
                            local index = findItem pathToIndex path
                            if index == 0 then (
                                append textureInfo #(path, #(#(obj, subMat)))
                                append pathToIndex path
                            ) else (
                                append textureInfo[index][2] #(obj, subMat)
                            )
                        )
                    )
                )
            ) else (
                -- 处理单一材质
                local diffuseMap = case classof obj.material of (
                    StandardMaterial: obj.material.diffuseMap
                    VRayMtl: obj.material.texmap_diffuse
                    PhysicalMaterial: obj.material.base_color_map
                    default: undefined
                )
                
                if diffuseMap != undefined and diffuseMap.filename != undefined then (
                    local path = diffuseMap.filename
                    local index = findItem pathToIndex path
                    if index == 0 then (
                        append textureInfo #(path, #(#(obj, obj.material)))
                        append pathToIndex path
                    ) else (
                        append textureInfo[index][2] #(obj, obj.material)
                    )
                )
            )
        )
    ) catch (
        format "收集贴图路径时出错: %\n" (getCurrentException())
    )
    
    return textureInfo
)

-- 贴图重命名历史管理
global textureRenameHistory = #()

fn loadTextureRenameHistory = (
    textureRenameHistory = #()
    local filePath = (getDir #temp) + "\\TextureRenameHistory.dat"
    if doesFileExist filePath then (
        local f = openFile filePath
        if f != undefined then (
            while not eof f do (
                local line = readLine f
                if line != undefined and line[1] != "#" then (
                    local parts = filterString line "\t"
                    if parts.count >= 3 do (
                        -- 改进的日期处理
                        local timestamp = try(parts[1] as integer)catch(parts[1])
                        append textureRenameHistory #(timestamp, parts[2], parts[3])
                    )
                )
            )
            close f
        )
    )
)

fn saveTextureRenameHistory = (
    local filePath = (getDir #temp) + "\\TextureRenameHistory.dat"
    local f = createFile filePath
    
    if f != undefined then (
        format "# 贴图重命名历史记录文件\n" to:f
        for rec in textureRenameHistory do (
            format "%\t%\t%\n" rec[1] rec[2] rec[3] to:f
        )
        close f
    )
)

-- 定义注册贴图重命名记录的全局函数
global registerTextureRename
fn registerTextureRename oldPath newPath = (
    -- 记录重命名历史
    try (
        -- 获取当前时间戳（确保是整数类型）
        local currentTime = timeStamp() as integer
        
        -- 添加到历史记录中，包含时间戳
        local record = #(
            currentTime, -- 添加时间戳，确保是整数
            oldPath,     -- 原文件路径
            newPath      -- 新文件路径
        )
        
        -- 加载现有历史
        loadTextureRenameHistory()
        
        -- 添加新记录
        append textureRenameHistory record
        
        -- 保存历史记录
        saveTextureRenameHistory()
        
        format "已记录贴图重命名: % -> %\n" oldPath newPath
        return true
    ) catch (
        format "记录贴图重命名历史出错: %\n" (getCurrentException())
        return false
    )
)

-- 定义贴图重命名撤回界面（移到全局范围）
-- 这是注释，表示这个rollout已经在文件前面定义过，不需要重复定义
-- 如需使用贴图重命名撤回功能，请参考前面的textureRollbackRollout定义

-- 这里是文件的其他内容
-- ... existing code ...

-- 定义贴图重命名撤回界面
rollout textureRollbackRollout "贴图重命名撤回" width:400 height:320 (
    -- 界面元素
    listbox lstHistory "重命名历史:" height:20 width:380
    button btnRollback "撤回所选" width:150 height:30 pos:[20,280]
    button btnRollbackAll "撤回全部" width:150 height:30 pos:[230,280]
    
    -- 初始化函数
    fn updateHistoryList = (
        loadTextureRenameHistory()
        -- 更新列表显示
        local items = #()
        for rec in textureRenameHistory do (
            try (
                -- 改进日期时间处理，增加错误处理
                local timeStr = ""
                
                -- 使用更安全的类型检查
                if rec[1] == undefined then (
                    timeStr = "[未知日期]"
                ) else if classOf rec[1] == Integer then (
                    try(
                        timeStr = formattedPrint (localTime rec[1]) format:"yyyy-MM-dd hh:mm:ss"
                    )catch(
                        timeStr = rec[1] as string
                    )
                ) else if classOf rec[1] == String then (
                    timeStr = rec[1]
                ) else (
                    timeStr = "[日期类型错误]"
                )
                
                local oldName = filenameFromPath rec[2]
                local newName = filenameFromPath rec[3]
                append items (timeStr + ": " + oldName + " → " + newName)
            ) catch (
                -- 如果处理单个记录出错，添加一个占位符
                append items "[记录格式错误]"
            )
        )
        lstHistory.items = items
    )
    
    -- 撤回一个重命名操作
    fn rollbackRename index = (
        if index > 0 and index <= textureRenameHistory.count then (
            local record = textureRenameHistory[index]
            local oldPath = record[2]
            local newPath = record[3]
            
            if doesFileExist newPath then (
                if not doesFileExist oldPath then (
                    -- 重命名文件回原始名称
                    local success = renameFile newPath oldPath
                    
                    if success then (
                        -- 更新所有使用该贴图的材质
                        for obj in objects do (
                            if obj.material != undefined then (
                                -- 处理多重材质
                                if classof obj.material == MultiMaterial then (
                                    for i = 1 to obj.material.numsubs do (
                                        local subMat = obj.material[i]
                                        if subMat != undefined then (
                                            -- 更新不同类型材质的贴图路径
                                            case classof subMat of (
                                                StandardMaterial: (
                                                    if subMat.diffuseMap != undefined and subMat.diffuseMap.filename == newPath then
                                                        subMat.diffuseMap.filename = oldPath
                                                )
                                                VRayMtl: (
                                                    if subMat.texmap_diffuse != undefined and subMat.texmap_diffuse.filename == newPath then
                                                        subMat.texmap_diffuse.filename = oldPath
                                                )
                                                PhysicalMaterial: (
                                                    if subMat.base_color_map != undefined and subMat.base_color_map.filename == newPath then
                                                        subMat.base_color_map.filename = oldPath
                                                )
                                            )
                                        )
                                    )
                                ) else (
                                    -- 处理单一材质
                                    case classof obj.material of (
                                        StandardMaterial: (
                                            if obj.material.diffuseMap != undefined and obj.material.diffuseMap.filename == newPath then
                                                obj.material.diffuseMap.filename = oldPath
                                        )
                                        VRayMtl: (
                                            if obj.material.texmap_diffuse != undefined and obj.material.texmap_diffuse.filename == newPath then
                                                obj.material.texmap_diffuse.filename = oldPath
                                        )
                                        PhysicalMaterial: (
                                            if obj.material.base_color_map != undefined and obj.material.base_color_map.filename == newPath then
                                                obj.material.base_color_map.filename = oldPath
                                        )
                                    )
                                )
                            )
                        )
                        
                        -- 从历史记录移除
                        deleteItem textureRenameHistory index
                        saveTextureRenameHistory()
                        return true
                    ) else (
                        messageBox "文件重命名失败，可能是权限问题或文件被占用。" title:"错误"
                    )
                ) else (
                    messageBox "原始文件路径已被占用，无法撤回。" title:"错误"
                )
            ) else (
                messageBox ("找不到重命名后的文件: " + newPath + "，无法撤回。") title:"错误"
            )
        )
        return false
    )
    
    -- 事件处理
    on textureRollbackRollout open do (
        try(updateHistoryList())catch(messageBox ("更新历史列表出错: " + (getCurrentException())) title:"错误")
    )
    
    on btnRollback pressed do (
        local sel = lstHistory.selection
        if sel > 0 then (
            if rollbackRename sel then (
                updateHistoryList()
                messageBox "撤回操作成功！" title:"成功"
            )
        ) else (
            messageBox "请先选择一条历史记录。" title:"提示"
        )
    )
    
    on btnRollbackAll pressed do (
        local count = textureRenameHistory.count
        if count > 0 then (
            local q = queryBox "确定要撤回所有贴图重命名操作吗？" title:"确认" beep:false
            if q then (
                local success = 0
                
                for i = count to 1 by -1 do (
                    if rollbackRename i then success += 1
                )
                
                updateHistoryList()
                messageBox (success as string + " 个操作已成功撤回，" + (count - success) as string + " 个操作撤回失败。") title:"撤回结果"
            )
        ) else (
            messageBox "没有可撤回的贴图重命名历史。" title:"提示"
        )
    )
)
-- 将上面定义的rollout设为全局变量
global textureRollbackRollout

-- 贴图重命名历史管理

-- 添加获取最近2的幂次方数的函数
fn getNearestPowerOfTwo n = (
    if n <= 0 then return 1
    local power = 1
    while power < n do power *= 2
    -- 检查哪个2的幂次方更接近
    local lowerPower = power / 2
    if (n - lowerPower) < (power - n) then
        return lowerPower
    return power
)

-- 优化的贴图修复函数
fn fixTextureSize filePath = (
    try (
        -- 检查文件是否存在和可访问
        if not doesFileExist filePath then return #(false, "文件不存在")
        
        -- 使用安全位图操作器处理位图
        return g_bitmapOperator.withBitmap filePath (
            fn processBitmap bmap filePath = (
                try (
                    -- 获取尺寸
                    local w = bmap.width
                    local h = bmap.height
                    
                    -- 计算新的尺寸
                    local newW = getNearestPowerOfTwo w
                    local newH = getNearestPowerOfTwo h
                    
                    -- 如果尺寸已经是2的幂次方，则不需要处理
                    if w == newW and h == newH then (
                        return #(true, "尺寸已符合要求")
                    )
                    
                    -- 创建临时文件名
                    local fileDir = getFilenamePath filePath
                    local fileName = getFilenameFile filePath
                    local fileExt = getFilenameType filePath
                    local tempPath = fileDir + fileName + "_temp" + fileExt
                    
                    -- 创建新的位图
                    local newBmap = undefined
                    
                    try (
                        -- 使用资源管理器管理新位图
                        newBmap = bitmap newW newH filename:tempPath
                        g_resourceManager.registerBitmap newBmap
                        
                        -- 复制并缩放图像
                        copy bmap newBmap
                        
                        -- 保存新图像
                        save newBmap
                        
                        -- 关闭并清理新位图资源
                        close newBmap
                        g_resourceManager.unregisterBitmap newBmap
                        newBmap = undefined
                        
                        -- 替换原文件
                        if doesFileExist tempPath then (
                            try(deleteFile filePath)catch()
                            try(renameFile tempPath filePath)catch(
                                -- 如果重命名失败，尝试复制后删除
                                copyFile tempPath filePath
                                deleteFile tempPath
                            )
                        )
                        
                        return #(true, "已修改为 " + newW as string + "x" + newH as string)
                    ) catch (
                        -- 确保资源释放
                        if newBmap != undefined do (
                            try (
                                close newBmap
                                g_resourceManager.unregisterBitmap newBmap
                            ) catch ()
                        )
                        
                        throw  -- 重新抛出异常
                    )
                ) catch (
                    -- 记录错误信息
                    local errMsg = getCurrentException()
                    format "修复贴图出错: %\n" errMsg
                    return #(false, "修复失败: " + errMsg)
                )
            )
        )
        
    ) catch (
        -- 记录错误信息
        local errMsg = getCurrentException()
        format "修复贴图出错: %\n" errMsg
        return #(false, "修复失败: " + errMsg)
    )
)

