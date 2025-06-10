-- ModelSlicer.ms
-- 平面模型等分切割工具
-- 将单面平面模型按照均等的网格进行切割，并分离为多个独立的小模型

rollout ModelSlicerRollout "模型切割工具" width:300
(
    group "选择模型"
    (
        pickbutton btn_pickModel "选择要切割的平面模型" width:250 align:#center
        label lbl_selectedModel "未选择模型" align:#center
        label lbl_modelInfo "模型信息: 0面" align:#center
    )
    
    group "切割设置"
    (
        spinner spn_rows "行数:" range:[1, 100, 2] type:#integer align:#left width:120
        spinner spn_columns "列数:" range:[1, 100, 2] type:#integer align:#left width:120
        checkbox chk_createNewObjects "创建新对象" checked:true
        checkbox chk_deleteOriginal "删除原对象" checked:false
        checkbox chk_useOptimizedMethod "使用优化方法（推荐）" checked:true tooltip:"使用更快的切割算法，推荐用于大型模型"
        checkbox chk_applyRandomColors "应用随机线框颜色" checked:false tooltip:"为切割后的每个对象应用随机线框颜色"
    )
    
    group "高级设置"
    (
        checkbox chk_useBatchProcessing "批处理模式" checked:true tooltip:"分批处理大型模型，减少内存占用"
        spinner spn_batchSize "批处理大小:" range:[100, 10000, 1000] type:#integer align:#left width:120 tooltip:"每批处理的最大面数"
        checkbox chk_useMemoryOptimization "内存优化" checked:true tooltip:"定期执行垃圾回收，减少内存占用"
        checkbox chk_backgroundProcessing "后台处理" checked:false tooltip:"允许在后台处理，保持界面响应"
        spinner spn_simplificationThreshold "简化阈值:" range:[0, 100, 0] type:#integer align:#left width:120 tooltip:"0表示不简化，其他值表示简化百分比"
    )
    
    group "执行"
    (
        button btn_execute "执行切割" width:250 height:30 align:#center
        button btn_cancel "取消操作" width:250 height:20 align:#center enabled:false
        progressBar pb_progress color:blue value:0 width:250 align:#center
    )
    
    group "颜色工具"
    (
        button btn_applyRandomColors "为选中对象应用随机线框颜色" width:250 height:30 align:#center tooltip:"为当前选中的所有对象应用随机线框颜色"
    )
    
    group "状态"
    (
        label lbl_status "就绪" align:#center
    )
    
    local selectedObj = undefined
    local processingActive = false
    local cancelRequested = false
    
    -- 生成随机颜色
    fn getRandomColor = 
    (
        -- 生成高饱和度、中等亮度的随机颜色
        local h = random 0.0 1.0
        local s = random 0.7 1.0
        local v = random 0.5 0.9
        
        -- 将HSV转换为RGB
        local hi = floor(h * 6)
        local f = h * 6 - hi
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        
        local r, g, b
        
        case hi of
        (
            0: (r = v; g = t; b = p)
            1: (r = q; g = v; b = p)
            2: (r = p; g = v; b = t)
            3: (r = p; g = q; b = v)
            4: (r = t; g = p; b = v)
            default: (r = v; g = p; b = q)
        )
        
        -- 返回颜色
        return color (r*255) (g*255) (b*255)
    )
    
    -- 内存优化：强制垃圾回收
    fn forceGarbageCollection =
    (
        gc()
        
        -- 尝试释放更多内存
        for i = 1 to 3 do (
            gc() -- 使用正确的垃圾回收函数
            windows.processPostedMessages()
        )
    )
    
    -- 检查对象是否适合处理
    fn checkObjectSuitability obj =
    (
        local faceCount = 0
        
        if (classof obj == Editable_Poly) then
            faceCount = obj.faces.count
        else if (classof obj == Editable_mesh) then
            faceCount = obj.numfaces
        else
        (
            local tempObj = copy obj
            convertToPoly tempObj
            faceCount = tempObj.faces.count
            delete tempObj
        )
        
        return #(faceCount)
    )
    
    -- 更新UI响应性
    fn updateUIResponsiveness =
    (
        -- 处理消息队列，保持UI响应
        windows.processPostedMessages()
        
        -- 检查取消请求
        if cancelRequested then
            throw "用户取消了操作"
    )
    
    -- 应用随机线框颜色到对象
    fn applyRandomColorToObjects objArray =
    (
        -- 显示状态
        lbl_status.text = "正在应用随机线框颜色..."
        
        -- 进度初始化
        pb_progress.value = 0
        local totalObjs = objArray.count
        
        for i = 1 to totalObjs do
        (
            local obj = objArray[i]
            
            -- 更新进度
            pb_progress.value = 100.0 * i / totalObjs
            
            -- 保持UI响应
            if (i mod 10) == 0 then
            (
                updateUIResponsiveness()
            )
            
            -- 设置随机线框颜色
            obj.wireColor = getRandomColor()
        )
        
        -- 更新状态
        lbl_status.text = "已应用随机线框颜色到 " + totalObjs as string + " 个对象"
        pb_progress.value = 100
    )
    
    -- 为选中对象应用随机颜色按钮事件
    on btn_applyRandomColors pressed do
    (
        local selObjects = getCurrentSelection()
        
        if selObjects.count == 0 then
        (
            messageBox "请先选择至少一个对象!" title:"错误"
            return()
        )
        
        applyRandomColorToObjects selObjects
    )
    
    -- 选择模型
    on btn_pickModel picked obj do
    (
        if obj != undefined then
        (
            selectedObj = obj
            lbl_selectedModel.text = obj.name
            
            -- 获取模型面数
            local objInfo = checkObjectSuitability obj
            local faceCount = objInfo[1]
            lbl_modelInfo.text = "模型信息: " + faceCount as string + "面"
            
            -- 根据面数推荐设置
            if faceCount > 100000 then
            (
                chk_useOptimizedMethod.checked = true
                chk_useBatchProcessing.checked = true
                chk_useMemoryOptimization.checked = true
                spn_batchSize.value = 5000
                lbl_status.text = "警告: 大型模型 (" + faceCount as string + "面), 已自动启用优化设置"
            )
            else
                lbl_status.text = "已选择模型：" + obj.name
        )
        else
        (
            lbl_selectedModel.text = "未选择模型"
            lbl_modelInfo.text = "模型信息: 0面"
            lbl_status.text = "请选择一个模型"
        )
    )
    
    -- 通过空间分区优化的切割方法
    fn spatialOptimizedSlice obj rows columns deleteOrig =
    (
        local resultObjects = #()
        
        -- 获取对象边界
        local objBounds = obj.max - obj.min
        local startPos = obj.min
        
        -- 计算每个切片的尺寸
        local sliceWidth = objBounds.x / columns
        local sliceHeight = objBounds.y / rows
        
        -- 创建一个空间分区网格来加速面的查找
        local cellSize = 10 -- 空间网格单元的大小
        local gridSizeX = ceil(objBounds.x / cellSize)
        local gridSizeY = ceil(objBounds.y / cellSize)
        local spatialGrid = #() -- 二维数组，存储每个网格单元内的面
        
        -- 初始化网格
        for i = 1 to gridSizeX do
        (
            spatialGrid[i] = #()
            for j = 1 to gridSizeY do
                spatialGrid[i][j] = #()
        )
        
        -- 制作一个副本作为工作对象
        local workObj = copy obj
        convertToPoly workObj
        
        -- 更新进度条
        pb_progress.value = 5
        updateUIResponsiveness()
        
        -- 将面添加到空间网格中
        lbl_status.text = "正在构建空间索引..."
        for f = 1 to workObj.faces.count do
        (
            local faceCenter = polyop.getFaceCenter workObj f
            
            -- 计算该面所在的网格单元
            local gridX = floor((faceCenter.x - startPos.x) / cellSize) + 1
            local gridY = floor((faceCenter.y - startPos.y) / cellSize) + 1
            
            -- 确保索引在有效范围内
            gridX = aMax 1 (aMin gridX gridSizeX)
            gridY = aMax 1 (aMin gridY gridSizeY)
            
            -- 将面索引添加到对应的网格单元
            append spatialGrid[gridX][gridY] f
            
            -- 定期更新UI和垃圾回收
            if (f mod 10000) == 0 then
            (
                pb_progress.value = 5 + (5.0 * f / workObj.faces.count)
                updateUIResponsiveness()
                
                if chk_useMemoryOptimization.checked and (f mod 50000) == 0 then
                (
                    forceGarbageCollection()
                )
            )
        )
        
        -- 更新进度条
        pb_progress.value = 10
        updateUIResponsiveness()
        
        -- 计算总切片数
        local totalSlices = rows * columns
        local currentSlice = 0
        
        -- 批处理设置
        local batchSize = spn_batchSize.value
        local useBatch = chk_useBatchProcessing.checked
        
        -- 为了提高性能，我们从最后一个开始，逐个分离
        for row = rows to 1 by -1 do
        (
            for col = columns to 1 by -1 do
            (
                -- 更新进度和UI
                currentSlice += 1
                pb_progress.value = 10 + (90.0 * currentSlice / totalSlices)
                lbl_status.text = "正在处理切片 " + currentSlice as string + "/" + totalSlices as string
                updateUIResponsiveness()
                
                if (row == 1 and col == 1) then
                (
                    -- 最后一个网格，不需要再分离
                    workObj.name = obj.name + "_R" + row as string + "C" + col as string
                    append resultObjects workObj
                )
                else
                (
                    -- 计算当前网格的边界
                    local minX = startPos.x + (col-1) * sliceWidth
                    local maxX = startPos.x + col * sliceWidth
                    local minY = startPos.y + (row-1) * sliceHeight
                    local maxY = startPos.y + row * sliceHeight
                    
                    -- 选择在当前网格内的面
                    local facesToDetach = #()
                    
                    -- 计算与当前切片重叠的网格单元
                    local gridMinX = floor((minX - startPos.x) / cellSize) + 1
                    local gridMaxX = floor((maxX - startPos.x) / cellSize) + 1
                    local gridMinY = floor((minY - startPos.y) / cellSize) + 1
                    local gridMaxY = floor((maxY - startPos.y) / cellSize) + 1
                    
                    -- 边界检查
                    gridMinX = aMax 1 (aMin gridMinX gridSizeX)
                    gridMaxX = aMax 1 (aMin gridMaxX gridSizeX)
                    gridMinY = aMax 1 (aMin gridMinY gridSizeY)
                    gridMaxY = aMax 1 (aMin gridMaxY gridSizeY)
                    
                    -- 只检查与当前切片重叠的网格单元
                    for gx = gridMinX to gridMaxX do
                    (
                        for gy = gridMinY to gridMaxY do
                        (
                            -- 对这个网格单元中的所有面进行检查
                            local cellFaces = spatialGrid[gx][gy]
                            for f in cellFaces do
                            (
                                -- 确保面仍然存在（没有被之前的操作删除）
                                if (polyop.getFaceDeg workObj f) > 0 then
                                (
                                    local faceCenter = polyop.getFaceCenter workObj f
                                    
                                    -- 检查面中心是否在当前网格内
                                    if faceCenter.x >= minX and faceCenter.x <= maxX and faceCenter.y >= minY and faceCenter.y <= maxY then
                                    (
                                        append facesToDetach f
                                    )
                                )
                            )
                        )
                    )
                    
                    -- 如果找到了面，就分离它们
                    if facesToDetach.count > 0 then
                    (
                        -- 批处理大型面集
                        if useBatch and facesToDetach.count > batchSize then
                        (
                            local batchCount = ceil (facesToDetach.count as float / batchSize)
                            local faceBatches = #()
                            
                            -- 分批
                            for b = 1 to batchCount do
                            (
                                local startIdx = (b-1) * batchSize + 1
                                local endIdx = aMin (b * batchSize) facesToDetach.count
                                
                                -- 创建批次
                                local batch = #()
                                for i = startIdx to endIdx do
                                    append batch facesToDetach[i]
                                
                                append faceBatches batch
                            )
                            
                            -- 分批处理
                            local newObjName = obj.name + "_R" + row as string + "C" + col as string
                            local newObjs = #()
                            
                            for b = 1 to faceBatches.count do
                            (
                                local batchName = newObjName + "_batch" + b as string
                                if b == faceBatches.count then
                                (
                                    batchName = newObjName
                                )
                                
                                polyop.detachFaces workObj faceBatches[b] delete:true asNode:true name:batchName
                                
                                local batchObj = getNodeByName batchName
                                if batchObj != undefined then
                                    append newObjs batchObj
                                
                                -- 更新UI和垃圾回收
                                if (b mod 5) == 0 then
                                (
                                    updateUIResponsiveness()
                                    if chk_useMemoryOptimization.checked then
                                    (
                                        forceGarbageCollection()
                                    )
                                )
                            )
                            
                            -- 如果产生了多个批次对象，合并它们
                            if newObjs.count > 1 then
                            (
                                local mergedObj = newObjs[1]
                                mergedObj.name = newObjName
                                
                                for i = 2 to newObjs.count do
                                (
                                    attach mergedObj newObjs[i]
                                )
                                
                                append resultObjects mergedObj
                            )
                            else if newObjs.count == 1 then
                            (
                                append resultObjects newObjs[1]
                            )
                        )
                        else
                        (
                            -- 标准处理方式 - 一次性分离所有面
                            local newObjName = obj.name + "_R" + row as string + "C" + col as string
                            polyop.detachFaces workObj facesToDetach delete:true asNode:true name:newObjName
                            
                            -- 获取刚创建的对象并添加到结果数组
                            local newObj = getNodeByName newObjName
                            if newObj != undefined then
                            (
                                append resultObjects newObj
                            )
                        )
                    )
                    
                    -- 内存优化
                    if chk_useMemoryOptimization.checked and (currentSlice mod 10) == 0 then
                    (
                        forceGarbageCollection()
                    )
                )
            )
        )
        
        -- 删除原始对象（如果需要）
        if deleteOrig then
        (
            delete obj
        )
        
        return resultObjects
    )
    
    -- 简化模型
    fn simplifyModel obj simplificationPercent =
    (
        if simplificationPercent <= 0 then
        (
            return obj
        )
        
        local simplifiedObj = copy obj
        convertToPoly simplifiedObj
        
        -- 计算要保留的面数
        local targetFaces = floor(simplifiedObj.faces.count * (1 - simplificationPercent/100.0))
        if targetFaces < 100 then
        (
            targetFaces = 100
        )
        
        -- 应用ProOptimizer修改器简化模型
        addModifier simplifiedObj (ProOptimizer())
        simplifiedObj.modifiers[1].VertexPercent = 100.0 * targetFaces / simplifiedObj.faces.count
        simplifiedObj.modifiers[1].Use_Vertex_Percent = true
        simplifiedObj.modifiers[1].Calculate = true
        
        -- 等待计算完成
        while simplifiedObj.modifiers[1].calculating do
        (
            sleep 0.1
            windows.processPostedMessages()
        )
        
        -- 崩溃修改器堆栈
        convertToPoly simplifiedObj
        
        return simplifiedObj
    )
    
    -- 取消按钮事件处理
    on btn_cancel pressed do
    (
        if processingActive then
        (
            cancelRequested = true
            lbl_status.text = "正在取消操作..."
        )
    )
    
    -- 执行切割
    on btn_execute pressed do
    (
        if selectedObj == undefined then
        (
            messageBox "请先选择一个模型!" title:"错误"
            return()
        )
        
        -- 获取设置
        local rows = spn_rows.value
        local columns = spn_columns.value
        local createNew = chk_createNewObjects.checked
        local deleteOrig = chk_deleteOriginal.checked
        local useOptimized = chk_useOptimizedMethod.checked
        local applyColors = chk_applyRandomColors.checked
        local simplificationThreshold = spn_simplificationThreshold.value
        local backgroundProcess = chk_backgroundProcessing.checked
        
        -- 设置处理状态
        processingActive = true
        cancelRequested = false
        btn_execute.enabled = false
        btn_cancel.enabled = true
        
        -- 开始切割
        lbl_status.text = "正在切割..."
        pb_progress.value = 0
        
        -- 冻结界面更新以提高性能
        if not backgroundProcess then
        (
            disableSceneRedraw()
        )
        
        try
        (
            local startTime = timestamp()
            local resultObjects = #()
            
            -- 预处理：简化模型（如有需要）
            local workObj = selectedObj
            if simplificationThreshold > 0 then
            (
                lbl_status.text = "正在简化模型..."
                pb_progress.value = 5
                workObj = simplifyModel selectedObj simplificationThreshold
                updateUIResponsiveness()
            )
            
            -- 内存优化：初始垃圾回收
            if chk_useMemoryOptimization.checked then
            (
                lbl_status.text = "正在优化内存..."
                forceGarbageCollection()
            )
            
            -- 根据选择的方法执行切割
            if useOptimized then
            (
                -- 使用空间分区优化的方法
                resultObjects = spatialOptimizedSlice workObj rows columns deleteOrig
            )
            else
            (
                -- 转换为可编辑多边形（如果不是）
                local objToCut = workObj
                if (classOf objToCut != Editable_Poly) and (classOf objToCut != PolyMeshObject) then
                (
                    -- 如果选择的是其他类型的对象，创建一个副本并转换为可编辑多边形
                    objToCut = copy workObj
                    convertToPoly objToCut
                )
                
                -- 获取对象的边界
                local objBounds = objToCut.max - objToCut.min
                local startPos = objToCut.min
                
                -- 计算每个切片的尺寸
                local sliceWidth = objBounds.x / columns
                local sliceHeight = objBounds.y / rows
                
                -- 创建结果数组
                
                -- 计算总步骤数用于进度显示
                local totalSteps = rows * columns
                local currentStep = 0
                
                -- 对每个网格执行切割
                for row = 1 to rows do
                (
                    for col = 1 to columns do
                    (
                        -- 更新进度
                        currentStep += 1
                        pb_progress.value = (100.0 * currentStep / totalSteps)
                        lbl_status.text = "正在处理切片 " + currentStep as string + "/" + totalSteps as string
                        updateUIResponsiveness()
                        
                        -- 创建切割平面的边界
                        local minX = startPos.x + (col-1) * sliceWidth
                        local maxX = startPos.x + col * sliceWidth
                        local minY = startPos.y + (row-1) * sliceHeight
                        local maxY = startPos.y + row * sliceHeight
                        
                        -- 创建新对象
                        local newObj = copy objToCut
                        newObj.name = objToCut.name + "_R" + row as string + "C" + col as string
                        
                        -- 选择位于切片外的顶点
                        local vertsToDelete = #()
                        
                        -- 遍历所有顶点
                        for v = 1 to newObj.verts.count do
                        (
                            local vertPos = newObj.verts[v].pos
                            
                            -- 检查顶点是否在当前网格之外
                            if vertPos.x < minX or vertPos.x > maxX or vertPos.y < minY or vertPos.y > maxY then
                            (
                                append vertsToDelete v
                            )
                            
                            -- 定期更新UI和执行垃圾回收
                            if (v mod 10000) == 0 then
                            (
                                updateUIResponsiveness()
                                
                                if chk_useMemoryOptimization.checked and (v mod 50000) == 0 then
                                (
                                    forceGarbageCollection()
                                )
                            )
                        )
                        
                        -- 删除切片外的顶点
                        if vertsToDelete.count > 0 then
                        (
                            polyop.deleteVerts newObj vertsToDelete
                        )
                        
                        -- 清理无效的元素
                        polyop.deleteIsoVerts newObj
                        
                        -- 将对象添加到结果数组
                        append resultObjects newObj
                        
                        -- 内存优化
                        if chk_useMemoryOptimization.checked and (currentStep mod 10) == 0 then
                        (
                            forceGarbageCollection()
                        )
                    )
                )
                
                -- 删除原始对象（如果选择了此选项）
                if deleteOrig and objToCut != workObj then
                (
                    delete objToCut
                )
            )
            
            -- 如果不创建新对象，则删除所有分割后的对象，只保留原始对象
            if not createNew then
            (
                for obj in resultObjects do
                (
                    delete obj
                )
                resultObjects = #()
            )
            
            -- 如果选择了应用随机颜色，则应用
            if applyColors and resultObjects.count > 0 then
            (
                applyRandomColorToObjects resultObjects
            )
            
            -- 清理：如果模型被简化过，且不删除原件，则清理简化的临时副本
            if simplificationThreshold > 0 and workObj != selectedObj and not deleteOrig then
            (
                delete workObj
            )
            
            -- 计算执行时间
            local endTime = timestamp()
            local executionTime = ((endTime - startTime) / 1000.0)
            
            -- 更新状态
            lbl_status.text = "切割完成！创建了 " + (resultObjects.count as string) + " 个对象，耗时 " + (executionTime as string) + " 秒"
        )
        catch
        (
            local errMsg = getCurrentException()
            if cancelRequested then
                lbl_status.text = "操作被用户取消"
            else
                lbl_status.text = "切割过程中发生错误：" + errMsg
            
            -- 在发生错误时输出更详细的信息
            format "错误: %\n" errMsg
        )
        
        -- 恢复界面更新
        pb_progress.value = 100
        processingActive = false
        btn_execute.enabled = true
        btn_cancel.enabled = false
        cancelRequested = false
        
        if not backgroundProcess then
        (
            enableSceneRedraw()
            redrawViews()
        )
        
        -- 最终垃圾回收
        if chk_useMemoryOptimization.checked then
        (
            forceGarbageCollection()
        )
    )
)

-- 创建浮动窗口
createDialog ModelSlicerRollout

-- 如何使用：
-- 1. 在3ds Max中选择要切割的平面模型
-- 2. 点击"选择要切割的平面模型"按钮
-- 3. 设置行数和列数
-- 4. 对于大型模型，可以启用"批处理模式"和"内存优化"
-- 5. 对于特别大的模型，可以使用"简化阈值"先简化再切割
-- 6. 点击"执行切割"按钮
-- 7. 切割后的模型将会创建为独立的对象
-- 8. 可以使用"为选中对象应用随机线框颜色"按钮为任意选中对象应用随机线框颜色
-- 9. 如果处理时间过长，可以点击"取消操作"按钮中止处理 