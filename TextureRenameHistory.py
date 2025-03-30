"""
贴图重命名历史记录工具

这个Python脚本用于：
1. 读取和显示贴图重命名历史记录
2. 提供撤销单个或全部重命名操作的功能
3. 保存历史记录到JSON文件中
"""

import os
import sys
import json
import datetime
from PySide2 import QtWidgets, QtCore, QtGui
import pymxs

# 全局变量，用于保持对话框实例的引用
_dialog_instance = None

# 确保运行环境是3ds Max
try:
    rt = pymxs.runtime
except:
    print("此脚本只能在3ds Max中运行")
    sys.exit()

# 定义历史记录文件路径
HISTORY_FILE = os.path.join(rt.maxFilePath, "texture_rename_history.json")

class TextureRenameRecord:
    """贴图重命名记录类"""
    def __init__(self, old_path="", new_path="", timestamp=None, session_id=""):
        self.old_path = old_path
        self.new_path = new_path
        self.timestamp = timestamp or datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.session_id = session_id or datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    
    def to_dict(self):
        """转换为字典以便保存为JSON"""
        return {
            "old_path": self.old_path,
            "new_path": self.new_path,
            "timestamp": self.timestamp,
            "session_id": self.session_id
        }
    
    @classmethod
    def from_dict(cls, data):
        """从字典创建记录对象"""
        return cls(
            old_path=data.get("old_path", ""),
            new_path=data.get("new_path", ""),
            timestamp=data.get("timestamp", ""),
            session_id=data.get("session_id", "")
        )


class TextureRenameHistoryManager:
    """贴图重命名历史管理器"""
    def __init__(self):
        self.history = []
        self.load_history()
    
    def load_history(self):
        """从JSON文件加载历史记录"""
        if os.path.exists(HISTORY_FILE):
            try:
                with open(HISTORY_FILE, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    self.history = [TextureRenameRecord.from_dict(item) for item in data]
                print(f"已加载 {len(self.history)} 条历史记录")
            except Exception as e:
                print(f"加载历史记录出错: {e}")
                self.history = []
        else:
            print("历史记录文件不存在，将创建新文件")
            self.history = []
    
    def save_history(self):
        """保存历史记录到JSON文件"""
        try:
            with open(HISTORY_FILE, 'w', encoding='utf-8') as f:
                json.dump([record.to_dict() for record in self.history], f, ensure_ascii=False, indent=2)
            print(f"历史记录已保存到 {HISTORY_FILE}")
        except Exception as e:
            print(f"保存历史记录出错: {e}")
    
    def add_record(self, old_path, new_path, session_id=None):
        """添加新的重命名记录"""
        record = TextureRenameRecord(old_path, new_path, session_id=session_id)
        self.history.append(record)
        self.save_history()
        return record
    
    def undo_rename(self, record):
        """撤销单个重命名操作"""
        old_path = record.old_path
        new_path = record.new_path
        
        if not os.path.exists(new_path):
            print(f"文件不存在: {new_path}")
            return False
        
        try:
            # 确保目标目录存在
            target_dir = os.path.dirname(old_path)
            if not os.path.exists(target_dir):
                os.makedirs(target_dir, exist_ok=True)
            
            # 重命名文件
            if os.path.exists(old_path):
                # 如果原文件路径已存在其他文件，先尝试备份
                backup_path = old_path + ".bak"
                os.rename(old_path, backup_path)
            
            # 执行重命名
            os.rename(new_path, old_path)
            
            # 更新场景中的贴图路径引用
            self._update_texture_paths_in_scene(new_path, old_path)
            
            # 移除该记录
            self.history = [h for h in self.history if not (h.old_path == old_path and h.new_path == new_path)]
            self.save_history()
            return True
        except Exception as e:
            print(f"撤销重命名操作出错: {e}")
            return False
    
    def undo_all_renames_in_session(self, session_id):
        """撤销指定会话中的所有重命名操作"""
        session_records = [record for record in self.history if record.session_id == session_id]
        success_count = 0
        fail_count = 0
        
        # 从最新的记录开始撤销，以处理可能的依赖关系
        for record in reversed(session_records):
            if self.undo_rename(record):
                success_count += 1
            else:
                fail_count += 1
        
        return success_count, fail_count
    
    def _update_texture_paths_in_scene(self, old_path, new_path):
        """更新场景中的贴图路径引用"""
        try:
            # 遍历场景中所有材质
            for material in rt.sceneMaterials:
                # 根据材质类型处理
                if rt.classOf(material) == rt.Multimaterial:
                    for i in range(1, material.numsubs + 1):
                        submaterial = material[i]
                        self._update_material_texture_path(submaterial, old_path, new_path)
                else:
                    self._update_material_texture_path(material, old_path, new_path)
        except Exception as e:
            print(f"更新场景贴图路径出错: {e}")
    
    def _update_material_texture_path(self, material, old_path, new_path):
        """更新单个材质的贴图路径"""
        try:
            # 处理不同类型的材质
            if rt.classOf(material) == rt.StandardMaterial and material.diffuseMap is not None:
                if material.diffuseMap.filename == old_path:
                    material.diffuseMap.filename = new_path
            elif rt.classOf(material) == rt.VRayMtl and material.texmap_diffuse is not None:
                if material.texmap_diffuse.filename == old_path:
                    material.texmap_diffuse.filename = new_path
            elif rt.classOf(material) == rt.PhysicalMaterial and material.base_color_map is not None:
                if material.base_color_map.filename == old_path:
                    material.base_color_map.filename = new_path
        except:
            pass


class TextureRenameHistoryDialog(QtWidgets.QDialog):
    """贴图重命名历史记录对话框"""
    def __init__(self, parent=None):
        super(TextureRenameHistoryDialog, self).__init__(parent)
        
        self.manager = TextureRenameHistoryManager()
        
        self.setWindowTitle("贴图重命名历史记录")
        self.setMinimumSize(800, 600)
        
        # 设置窗口标志，使其保持在前台但不阻塞其他窗口
        self.setWindowFlags(QtCore.Qt.Window | QtCore.Qt.WindowStaysOnTopHint)
        
        self.init_ui()
        self.load_data()
    
    def init_ui(self):
        """初始化UI界面"""
        layout = QtWidgets.QVBoxLayout(self)
        
        # 会话列表
        session_group = QtWidgets.QGroupBox("重命名会话")
        session_layout = QtWidgets.QVBoxLayout(session_group)
        
        self.session_list = QtWidgets.QListWidget()
        self.session_list.setSelectionMode(QtWidgets.QAbstractItemView.SingleSelection)
        self.session_list.itemSelectionChanged.connect(self.on_session_selected)
        session_layout.addWidget(self.session_list)
        
        # 记录列表
        record_group = QtWidgets.QGroupBox("重命名记录")
        record_layout = QtWidgets.QVBoxLayout(record_group)
        
        self.record_table = QtWidgets.QTableWidget()
        self.record_table.setColumnCount(3)
        self.record_table.setHorizontalHeaderLabels(["原文件路径", "新文件路径", "重命名时间"])
        self.record_table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.record_table.setEditTriggers(QtWidgets.QAbstractItemView.NoEditTriggers)
        self.record_table.horizontalHeader().setStretchLastSection(True)
        self.record_table.horizontalHeader().setSectionResizeMode(QtWidgets.QHeaderView.Stretch)
        record_layout.addWidget(self.record_table)
        
        # 分割窗口
        splitter = QtWidgets.QSplitter(QtCore.Qt.Vertical)
        splitter.addWidget(session_group)
        splitter.addWidget(record_group)
        splitter.setSizes([200, 400])
        
        layout.addWidget(splitter)
        
        # 按钮区域
        button_layout = QtWidgets.QHBoxLayout()
        
        self.undo_selected_btn = QtWidgets.QPushButton("撤销选中重命名")
        self.undo_selected_btn.clicked.connect(self.undo_selected_rename)
        self.undo_selected_btn.setEnabled(False)
        
        self.undo_session_btn = QtWidgets.QPushButton("撤销选中会话")
        self.undo_session_btn.clicked.connect(self.undo_session_renames)
        self.undo_session_btn.setEnabled(False)
        
        self.refresh_btn = QtWidgets.QPushButton("刷新")
        self.refresh_btn.clicked.connect(self.refresh_data)
        
        self.close_btn = QtWidgets.QPushButton("关闭")
        self.close_btn.clicked.connect(self.close)
        
        button_layout.addWidget(self.undo_selected_btn)
        button_layout.addWidget(self.undo_session_btn)
        button_layout.addWidget(self.refresh_btn)
        button_layout.addWidget(self.close_btn)
        
        layout.addLayout(button_layout)
        
        # 连接事件
        self.record_table.itemSelectionChanged.connect(self.on_record_selected)
    
    def load_data(self):
        """加载数据到界面"""
        # 加载会话列表
        self.session_list.clear()
        
        # 获取唯一的会话ID及其包含的记录数量
        sessions = {}
        for record in self.manager.history:
            if record.session_id in sessions:
                sessions[record.session_id]['count'] += 1
            else:
                # 使用第一个记录的时间戳作为会话时间
                sessions[record.session_id] = {'timestamp': record.timestamp, 'count': 1}
        
        # 按时间排序会话
        sorted_sessions = sorted(sessions.items(), key=lambda x: x[1]['timestamp'], reverse=True)
        
        for session_id, info in sorted_sessions:
            item = QtWidgets.QListWidgetItem(f"{info['timestamp']} ({info['count']} 个记录)")
            item.setData(QtCore.Qt.UserRole, session_id)
            self.session_list.addItem(item)
    
    def on_session_selected(self):
        """会话选中事件"""
        self.record_table.clearContents()
        self.record_table.setRowCount(0)
        
        selected_items = self.session_list.selectedItems()
        if not selected_items:
            self.undo_session_btn.setEnabled(False)
            return
        
        self.undo_session_btn.setEnabled(True)
        session_id = selected_items[0].data(QtCore.Qt.UserRole)
        
        # 显示该会话中的记录
        session_records = [r for r in self.manager.history if r.session_id == session_id]
        self.record_table.setRowCount(len(session_records))
        
        for i, record in enumerate(session_records):
            self.record_table.setItem(i, 0, QtWidgets.QTableWidgetItem(record.old_path))
            self.record_table.setItem(i, 1, QtWidgets.QTableWidgetItem(record.new_path))
            self.record_table.setItem(i, 2, QtWidgets.QTableWidgetItem(record.timestamp))
    
    def on_record_selected(self):
        """记录选中事件"""
        self.undo_selected_btn.setEnabled(len(self.record_table.selectedItems()) > 0)
    
    def undo_selected_rename(self):
        """撤销选中的重命名操作"""
        selected_rows = set(index.row() for index in self.record_table.selectedIndexes())
        if not selected_rows:
            return
        
        selected_items = self.session_list.selectedItems()
        if not selected_items:
            return
        
        session_id = selected_items[0].data(QtCore.Qt.UserRole)
        session_records = [r for r in self.manager.history if r.session_id == session_id]
        
        success_count = 0
        fail_count = 0
        
        for row in selected_rows:
            if 0 <= row < len(session_records):
                record = session_records[row]
                if self.manager.undo_rename(record):
                    success_count += 1
                else:
                    fail_count += 1
        
        # 显示结果
        msg = f"撤销操作完成\n成功: {success_count}\n失败: {fail_count}"
        QtWidgets.QMessageBox.information(self, "撤销结果", msg)
        
        # 刷新数据
        self.refresh_data()
    
    def undo_session_renames(self):
        """撤销选中会话中的所有重命名操作"""
        selected_items = self.session_list.selectedItems()
        if not selected_items:
            return
        
        session_id = selected_items[0].data(QtCore.Qt.UserRole)
        
        # 确认对话框
        reply = QtWidgets.QMessageBox.question(
            self, 
            "确认撤销", 
            f"确定要撤销此会话中的所有重命名操作吗？",
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No
        )
        
        if reply == QtWidgets.QMessageBox.Yes:
            success_count, fail_count = self.manager.undo_all_renames_in_session(session_id)
            
            # 显示结果
            msg = f"撤销会话操作完成\n成功: {success_count}\n失败: {fail_count}"
            QtWidgets.QMessageBox.information(self, "撤销结果", msg)
            
            # 刷新数据
            self.refresh_data()
    
    def refresh_data(self):
        """刷新数据"""
        self.manager.load_history()
        self.load_data()
        self.record_table.clearContents()
        self.record_table.setRowCount(0)
        self.undo_selected_btn.setEnabled(False)
    
    def closeEvent(self, event):
        """重写关闭事件，确保全局引用被清除"""
        global _dialog_instance
        _dialog_instance = None
        event.accept()


# 添加监听贴图重命名的功能
def add_texture_rename_hook():
    """添加监听贴图重命名的钩子"""
    # 这部分需要在MAXScript中实现，通过Python调用MAXScript
    max_script = """
    -- 创建全局函数用于从Python注册重命名记录
    global registerTextureRename
    fn registerTextureRename oldPath newPath = (
        python.Execute ("import sys; sys.path.append('" + (getDir #scripts) + "')")
        python.Execute ("import TextureRenameHistory as trh")
        python.Execute ("manager = trh.TextureRenameHistoryManager()")
        python.Execute ("manager.add_record('" + oldPath + "', '" + newPath + "')")
    )
    """
    rt.execute(max_script)


# 主函数
def main():
    global _dialog_instance
    
    # 如果对话框已经打开，则将其提到前台
    if _dialog_instance is not None and not _dialog_instance.isHidden():
        _dialog_instance.activateWindow()
        _dialog_instance.raise_()
        return
    
    # 添加监听钩子
    add_texture_rename_hook()
    
    # 创建QApplication
    app = QtWidgets.QApplication.instance()
    if not app:
        app = QtWidgets.QApplication(sys.argv)
    
    # 显示对话框（非模态）
    dialog = TextureRenameHistoryDialog()
    dialog.show()  # 使用show()代替exec_()显示为非模态对话框
    
    # 保持对话框的引用，防止被垃圾回收
    _dialog_instance = dialog


if __name__ == "__main__":
    main() 