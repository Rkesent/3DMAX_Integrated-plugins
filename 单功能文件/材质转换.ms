-- 递归函数，用于转换材质
fn convertMaterial mtl =
(
    if classof mtl == VRayMtl then (
        -- 创建一个新的标准材质
        newMtl = StandardMaterial()
        -- 保留材质名称
        newMtl.name = mtl.name
        -- 将 VR 材质的颜色和贴图复制到标准材质
        newMtl.diffuse = mtl.diffuse
        newMtl.specular = mtl.reflection
        newMtl.glossiness = mtl.reflectionGlossiness
        -- 复制贴图
        if mtl.diffuseMap != undefined do newMtl.diffuseMap = mtl.diffuseMap
        if mtl.reflectionMap != undefined do newMtl.specularMap = mtl.reflectionMap
        return newMtl
    )
    else if classof mtl == StandardMaterial then (
        -- 创建一个新的 VR 材质
        newMtl = VRayMtl()
        -- 保留材质名称
        newMtl.name = mtl.name
        -- 将标准材质的颜色和贴图复制到 VR 材质
        newMtl.diffuse = mtl.diffuse
        newMtl.reflection = mtl.specular
        newMtl.reflectionGlossiness = mtl.glossiness
        -- 复制贴图
        if mtl.diffuseMap != undefined do newMtl.diffuseMap = mtl.diffuseMap
        if mtl.specularMap != undefined do newMtl.reflectionMap = mtl.specularMap
        return newMtl
    )
    else if classof mtl == MultiMaterial then (
        -- 处理多维子材质
        for i = 1 to mtl.numsubs do (
            mtl[i] = convertMaterial mtl[i]
        )
        return mtl
    )
    else (
        -- 如果材质类型不匹配，返回原材质
        return mtl
    )
)

-- 创建一个简单的对话框
rollout MaterialConverter "材质转换器" (
    -- 添加按钮用于转换材质
    button btnConvertToStandard "转换为标准材质" width:150
    button btnConvertToVRay "转换为VR材质" width:150

    -- 定义按钮的事件处理
    on btnConvertToStandard pressed do (
        -- 遍历场景中的所有材质
        for i = 1 to scenematerials.count do (
            scenematerials[i] = convertMaterial scenematerials[i]
        )
    )

    on btnConvertToVRay pressed do (
        -- 遍历场景中的所有材质
        for i = 1 to scenematerials.count do (
            scenematerials[i] = convertMaterial scenematerials[i]
        )
    )
)

-- 显示对话框
createDialog MaterialConverter
