import concurrent.futures
import os
import json

def check_material(material):
    # 模拟材质检查逻辑
    if not os.path.exists(material['diffuseMap']):
        return material
    return None

def main(materials):
    missing_maps = []
    with concurrent.futures.ThreadPoolExecutor() as executor:
        results = executor.map(check_material, materials)
        for result in results:
            if result:
                missing_maps.append(result)
    return missing_maps

if __name__ == "__main__":
    import sys
    materials = json.loads(sys.argv[1])
    missing_maps = main(materials)
    print(json.dumps(missing_maps))