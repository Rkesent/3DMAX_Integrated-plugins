import os
import json
import hashlib
import shutil
from PySide2 import QtWidgets, QtCore, QtGui
import pymxs
import time

# Get the MaxPlus module
rt = pymxs.runtime

# Define color scheme
DARK_GRAY = "#333333"
MID_GRAY = "#444444"
LIGHT_GRAY = "#666666"
HIGHLIGHT = "#5D8AA8"  # Soft blue highlight, similar to 3ds Max's selection color
TEXT_COLOR = "#E0E0E0"
BUTTON_COLOR = "#555555"
BUTTON_HOVER = "#666666"
BUTTON_PRESSED = "#444444"
WARNING_COLOR = "#F5A623"  # Warning color for duplicate items

class StyleHelper:
    @staticmethod
    def get_main_style():
        return f"""
            QDialog {{
                background-color: {DARK_GRAY};
                color: {TEXT_COLOR};
                border: 1px solid {LIGHT_GRAY};
            }}
            QTableWidget {{
                background-color: {MID_GRAY};
                color: {TEXT_COLOR};
                gridline-color: {LIGHT_GRAY};
                border: none;
            }}
            QTableWidget::item {{
                padding: 5px;
                border-bottom: 1px solid {LIGHT_GRAY};
            }}
            QTableWidget::item:selected {{
                background-color: {HIGHLIGHT};
            }}
            QHeaderView::section {{
                background-color: {DARK_GRAY};
                color: {TEXT_COLOR};
                padding: 5px;
                border: 1px solid {LIGHT_GRAY};
            }}
            QPushButton {{
                background-color: {BUTTON_COLOR};
                color: {TEXT_COLOR};
                border: 1px solid {LIGHT_GRAY};
                border-radius: 3px;
                padding: 8px 15px;
                font-weight: bold;
            }}
            QPushButton:hover {{
                background-color: {BUTTON_HOVER};
            }}
            QPushButton:pressed {{
                background-color: {BUTTON_PRESSED};
            }}
            QLabel {{
                color: {TEXT_COLOR};
            }}
            QProgressBar {{
                border: 1px solid {LIGHT_GRAY};
                border-radius: 3px;
                background-color: {MID_GRAY};
                color: {TEXT_COLOR};
                text-align: center;
            }}
            QProgressBar::chunk {{
                background-color: {HIGHLIGHT};
                width: 10px;
            }}
            QCheckBox {{
                color: {TEXT_COLOR};
            }}
            QCheckBox::indicator {{
                width: 13px;
                height: 13px;
            }}
            QCheckBox::indicator:checked {{
                background-color: {HIGHLIGHT};
            }}
        """

class ProgressDialog(QtWidgets.QDialog):
    """Custom progress dialog for longer operations"""
    def __init__(self, parent=None, title="处理中...", max_value=100):
        super(ProgressDialog, self).__init__(parent)
        self.setWindowTitle(title)
        self.setFixedSize(350, 120)
        self.setWindowFlags(QtCore.Qt.WindowStaysOnTopHint)
        self.setStyleSheet(StyleHelper.get_main_style())
        
        layout = QtWidgets.QVBoxLayout()
        self.setLayout(layout)
        layout.setContentsMargins(15, 15, 15, 15)
        
        self.label = QtWidgets.QLabel("正在处理...")
        self.label.setAlignment(QtCore.Qt.AlignCenter)
        layout.addWidget(self.label)
        
        self.progress_bar = QtWidgets.QProgressBar()
        self.progress_bar.setRange(0, max_value)
        self.progress_bar.setValue(0)
        self.progress_bar.setTextVisible(True)
        layout.addWidget(self.progress_bar)
    
    def set_value(self, value):
        """Update the progress bar value"""
        self.progress_bar.setValue(value)
        QtWidgets.QApplication.processEvents()
    
    def set_label(self, text):
        """Update the label text"""
        self.label.setText(text)
        QtWidgets.QApplication.processEvents()

class TextureManager(QtWidgets.QDialog):
    def __init__(self, parent=None):
        super(TextureManager, self).__init__(parent)
        self.setWindowTitle("贴图管理工具")
        self.setMinimumWidth(900)
        self.setMinimumHeight(500)
        self.setStyleSheet(StyleHelper.get_main_style())
        # 使用标准对话框窗口，但不设置模态或全局置顶
        self.setWindowFlags(QtCore.Qt.Window | QtCore.Qt.WindowTitleHint | QtCore.Qt.WindowCloseButtonHint | QtCore.Qt.CustomizeWindowHint)
        self.initUI()
        self.texture_data = []
        self.texture_map_objects = {}  # Store texture objects by hash for later use
        self.duplicate_textures = []  # Store hash values of duplicate textures
        self.auto_run = False  # 记录是否是自动运行模式
        self.modification_count = 1  # 记录修改次数的计数器
    
    def initUI(self):
        # Main layout
        main_layout = QtWidgets.QVBoxLayout()
        main_layout.setSpacing(10)
        main_layout.setContentsMargins(15, 15, 15, 15)
        self.setLayout(main_layout)
        
        # Add a header label
        header_label = QtWidgets.QLabel("贴图管理工具")
        header_label.setStyleSheet(f"font-size: 16px; font-weight: bold; color: {TEXT_COLOR}; margin-bottom: 10px;")
        header_label.setAlignment(QtCore.Qt.AlignCenter)
        main_layout.addWidget(header_label)
        
        # Content layout with table on left and buttons on right
        content_layout = QtWidgets.QHBoxLayout()
        content_layout.setSpacing(15)
        main_layout.addLayout(content_layout)
        
        # Left side container with border
        left_container = QtWidgets.QWidget()
        left_container.setStyleSheet(f"background-color: {MID_GRAY}; border-radius: 5px;")
        left_layout = QtWidgets.QVBoxLayout(left_container)
        
        # Create table for texture information
        self.table = QtWidgets.QTableWidget()
        self.table.setColumnCount(4)  # 初始列数：哈希值、是否引用、原始名称、修改后名称(1)
        self.table.setHorizontalHeaderLabels(["哈希值", "贴图是否引用", "原始贴图名称", "修改后名称(1)"])
        self.table.setSelectionBehavior(QtWidgets.QAbstractItemView.SelectRows)
        self.table.setEditTriggers(QtWidgets.QAbstractItemView.DoubleClicked)  # Allow editing on double click
        self.table.horizontalHeader().setSectionResizeMode(QtWidgets.QHeaderView.Stretch)
        self.table.setShowGrid(True)
        self.table.setAlternatingRowColors(True)
        self.table.setStyleSheet(
            f"QTableWidget {{ alternate-background-color: {DARK_GRAY}; }}"
            f"QTableWidget::item {{ border-bottom: 1px solid {LIGHT_GRAY}; }}"
        )
        self.table.cellChanged.connect(self.on_cell_changed)
        self.table.verticalHeader().setVisible(False)  # Hide vertical header
        left_layout.addWidget(self.table)
        
        content_layout.addWidget(left_container, 3)
        
        # Right side buttons container with border
        right_container = QtWidgets.QWidget()
        right_container.setStyleSheet(f"background-color: {MID_GRAY}; border-radius: 5px;")
        right_layout = QtWidgets.QVBoxLayout(right_container)
        right_layout.setSpacing(15)
        right_layout.setContentsMargins(15, 15, 15, 15)
        content_layout.addWidget(right_container, 1)
        
        # Buttons for main actions
        action_label = QtWidgets.QLabel("操作")
        action_label.setStyleSheet("font-weight: bold; padding-bottom: 5px; border-bottom: 1px solid #777;")
        right_layout.addWidget(action_label)
        
        # Record button with icon
        self.record_btn = self.create_button("记录", "查找场景中的所有贴图并记录")
        right_layout.addWidget(self.record_btn)
        
        # Revert buttons
        right_layout.addSpacing(10)
        revert_label = QtWidgets.QLabel("撤回操作")
        revert_label.setStyleSheet("font-weight: bold; padding-bottom: 5px; border-bottom: 1px solid #777;")
        right_layout.addWidget(revert_label)
        
        self.revert_selected_btn = self.create_button("撤回到选中名称", "将选中的贴图恢复到原始名称")
        right_layout.addWidget(self.revert_selected_btn)
        
        self.revert_all_btn = self.create_button("全部撤回到上一步命名", "将所有贴图恢复到原始名称")
        right_layout.addWidget(self.revert_all_btn)

        # Duplicate texture handling
        right_layout.addSpacing(10)
        duplicate_label = QtWidgets.QLabel("重复贴图处理")
        duplicate_label.setStyleSheet("font-weight: bold; padding-bottom: 5px; border-bottom: 1px solid #777;")
        right_layout.addWidget(duplicate_label)
        
        # Checkbox for texture archiving
        self.archive_checkbox = QtWidgets.QCheckBox("将贴图归档")
        self.archive_checkbox.setToolTip("在处理重复贴图时将贴图复制到maps文件夹")
        right_layout.addWidget(self.archive_checkbox)
        
        # Handle duplicates button
        self.handle_duplicates_btn = self.create_button("处理重复贴图", "检测和处理场景中的重复贴图")
        right_layout.addWidget(self.handle_duplicates_btn)
        
        # Import/Export section
        right_layout.addSpacing(10)
        import_export_label = QtWidgets.QLabel("导入/导出")
        import_export_label.setStyleSheet("font-weight: bold; padding-bottom: 5px; border-bottom: 1px solid #777;")
        right_layout.addWidget(import_export_label)
        
        # Import/Export buttons in a horizontal layout
        import_export_layout = QtWidgets.QHBoxLayout()
        import_export_layout.setSpacing(10)
        
        self.import_btn = self.create_button("导入记录值", "从JSON文件导入贴图记录")
        self.export_btn = self.create_button("导出记录值", "将贴图记录导出为JSON文件")
        
        import_export_layout.addWidget(self.import_btn)
        import_export_layout.addWidget(self.export_btn)
        right_layout.addLayout(import_export_layout)
        
        # Add stretch to push all buttons to the top
        right_layout.addStretch(1)
        
        # Status bar at the bottom
        self.status_bar = QtWidgets.QLabel("准备就绪")
        self.status_bar.setStyleSheet(f"color: {TEXT_COLOR}; background-color: {DARK_GRAY}; padding: 5px; border-radius: 3px;")
        main_layout.addWidget(self.status_bar)
        
        # Connect buttons to functions
        self.record_btn.clicked.connect(self.record_textures)
        self.revert_selected_btn.clicked.connect(self.revert_to_selected)
        self.revert_all_btn.clicked.connect(self.revert_all)
        self.import_btn.clicked.connect(self.import_records)
        self.export_btn.clicked.connect(self.export_records)
        self.handle_duplicates_btn.clicked.connect(self.handle_duplicate_textures)
        
        # Flag to prevent recursive calls in cell changed event
        self.is_updating_table = False
    
    def create_button(self, text, tooltip=""):
        """Create a styled button with optional tooltip"""
        button = QtWidgets.QPushButton(text)
        if tooltip:
            button.setToolTip(tooltip)
        button.setCursor(QtCore.Qt.PointingHandCursor)
        return button
    
    def on_cell_changed(self, row, column):
        """Handle cell edits"""
        if self.is_updating_table or column != 3:  # Only handle modified name column
            return
            
        self.is_updating_table = True
        try:
            # Get the hash value and original texture info
            hash_value = self.table.item(row, 0).text()
            new_name = self.table.item(row, 3).text().strip()
            
            # Find the texture in our data
            texture_info = next((item for item in self.texture_data if item["hash"] == hash_value), None)
            
            if texture_info and hash_value in self.texture_map_objects:
                texture = self.texture_map_objects[hash_value]
                
                if texture and hasattr(texture, 'filename'):
                    # Update the data
                    texture_info["modified(1)"] = new_name
                    
                    # Get current path
                    current_path = texture.filename
                    dir_path = os.path.dirname(current_path)
                    
                    # Create the new path
                    new_path = os.path.join(dir_path, new_name)
                    
                    # Update the texture in 3ds Max if the file exists or user confirms
                    if os.path.exists(dir_path):
                        # Check if this would overwrite an existing file
                        if os.path.exists(new_path) and new_path != current_path:
                            reply = QtWidgets.QMessageBox.question(
                                self, "确认覆盖", 
                                f"文件 {new_name} 已存在，确定要覆盖吗？\n这将重命名贴图引用但不会重命名文件。",
                                QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No
                            )
                            
                            if reply == QtWidgets.QMessageBox.Yes:
                                with rt.undo(True):
                                    texture.filename = new_path
                            else:
                                # Reset to original value
                                self.table.item(row, 3).setText(texture_info["modified(1)"])
                        else:
                            # No conflict, update directly
                            with rt.undo(True):
                                texture.filename = new_path
        except Exception as e:
            rt.messageBox("更新贴图名称失败: {}".format(str(e)))
        finally:
            self.is_updating_table = False
        
    def find_duplicate_textures(self):
        """Find duplicate textures by hash value"""
        if not self.texture_data:
            return []
            
        # Create dictionary to store textures by hash
        hash_dict = {}
        duplicates = []
        
        for item in self.texture_data:
            hash_value = item["hash"]
            if hash_value.startswith("File not found") or hash_value.startswith("Error"):
                continue
                
            if hash_value in hash_dict:
                # This is a duplicate
                if hash_value not in duplicates:
                    duplicates.append(hash_value)
            else:
                hash_dict[hash_value] = True
                
        return duplicates
    
    def handle_duplicate_textures(self):
        """Handle duplicate textures - detect and offer options to resolve"""
        if not self.texture_data:
            self.status_bar.setText("没有贴图记录，请先使用记录功能")
            rt.messageBox("请先使用记录功能扫描场景中的贴图.")
            return
            
        # Find duplicate textures
        self.status_bar.setText("正在检测重复贴图...")
        
        # Find duplicates with same hash values
        self.duplicate_textures = self.find_duplicate_textures()
        
        if not self.duplicate_textures:
            self.status_bar.setText("没有发现重复贴图")
            rt.messageBox("没有发现重复贴图.")
            return
            
        # Found duplicates, ask user what to do
        duplicate_count = len(self.duplicate_textures)
        affected_textures = sum(1 for item in self.texture_data if item["hash"] in self.duplicate_textures)
        
        reply = QtWidgets.QMessageBox.question(
            self, "发现重复贴图", 
            f"发现 {duplicate_count} 个重复贴图，涉及 {affected_textures} 个贴图引用。\n\n"
            "是否要处理这些重复贴图？这将使所有贴图引用指向同一个文件。",
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No
        )
        
        if reply != QtWidgets.QMessageBox.Yes:
            self.status_bar.setText("取消处理重复贴图")
            return
            
        # Process duplicates
        self.status_bar.setText("正在处理重复贴图...")
        progress = ProgressDialog(self, "处理重复贴图", len(self.duplicate_textures))
        progress.show()
        
        try:
            # Check if we need to archive textures
            should_archive = self.archive_checkbox.isChecked()
            maps_folder = None
            
            if should_archive:
                # Create maps folder if it doesn't exist
                scene_file = rt.maxFilePath
                if scene_file:
                    scene_dir = os.path.dirname(scene_file)
                    maps_folder = os.path.join(scene_dir, "maps")
                    if not os.path.exists(maps_folder):
                        os.makedirs(maps_folder)
            
            # Process each duplicate hash
            for i, hash_value in enumerate(self.duplicate_textures):
                progress.set_value(i+1)
                progress.set_label(f"正在处理重复贴图 {i+1} / {len(self.duplicate_textures)}")
                
                # Get all textures with this hash
                textures_with_hash = [item for item in self.texture_data if item["hash"] == hash_value]
                
                if textures_with_hash:
                    # Use the first texture as the reference
                    reference_texture = textures_with_hash[0]
                    reference_name = reference_texture["original"]
                    
                    # Get the texture object
                    if hash_value in self.texture_map_objects:
                        reference_texture_obj = self.texture_map_objects[hash_value]
                        reference_path = reference_texture_obj.filename
                        reference_dir = os.path.dirname(reference_path)
                        
                        # If archiving, copy the texture to the maps folder
                        if should_archive and maps_folder:
                            new_path = os.path.join(maps_folder, reference_name)
                            if reference_path != new_path and os.path.exists(reference_path):
                                # Copy file if it doesn't already exist
                                if not os.path.exists(new_path):
                                    shutil.copy2(reference_path, new_path)
                                reference_path = new_path
                                reference_dir = maps_folder
                        
                        # Update all textures with this hash to use the reference path
                        with rt.undo(True):
                            for texture_info in textures_with_hash:
                                texture_hash = texture_info["hash"]
                                if texture_hash in self.texture_map_objects:
                                    texture_obj = self.texture_map_objects[texture_hash]
                                    if texture_obj and hasattr(texture_obj, 'filename'):
                                        texture_obj.filename = reference_path
                                        
                                # Update the data
                                texture_info["modified(1)"] = reference_name
            
            # Update the table
            self.is_updating_table = True
            try:
                self.table.setRowCount(0)
                for item in self.texture_data:
                    self._add_row_to_table(
                        item["hash"],
                        item["referenced"],
                        item["original"],
                        item["modified(1)"],
                        item["hash"] in self.duplicate_textures  # Mark duplicate textures
                    )
            finally:
                self.is_updating_table = False
                
            self.status_bar.setText(f"已处理 {len(self.duplicate_textures)} 个重复贴图")
            rt.messageBox(f"已成功处理 {len(self.duplicate_textures)} 个重复贴图.")
                
        except Exception as e:
            error_msg = str(e)
            self.status_bar.setText(f"处理重复贴图失败: {error_msg}")
            rt.messageBox(f"处理重复贴图失败: {error_msg}")
        finally:
            progress.close()
    
    def record_textures(self, auto_run=False):
        """
        扫描场景中的贴图并记录到表格中
        按照流程图实现:
        1. 从场景文件根目录中尝试获取JSON文件
        2. 获取场景中使用的贴图
        3. 计算贴图哈希值
        4. 显示在表格中
        
        参数:
        auto_run: 是否是自动运行模式，如果是则不弹出确认对话框
        """
        self.auto_run = auto_run  # 记录是否是自动运行模式
        
        try:
            # 清除现有数据
            self.texture_data = []
            self.texture_map_objects = {}
            self.duplicate_textures = []
            self.table.setRowCount(0)
            
            # 更新状态
            self.status_bar.setText("正在扫描贴图...")
            
            # 第一步：尝试从场景文件根目录中获取JSON文件
            json_data = self._find_existing_json_record()
            existing_textures_dict = {}
            
            if json_data:
                self.status_bar.setText("找到现有记录，正在应用...")
                # 创建查找字典
                for item in json_data:
                    existing_textures_dict[item["hash"]] = item
                
                # 只在非自动运行模式下显示确认对话框
                if not self.auto_run:
                    # 通知用户获取成功
                    msg = QtWidgets.QMessageBox()
                    msg.setWindowTitle("获取成功")
                    msg.setText(f"成功从JSON文件中获取了 {len(json_data)} 条贴图记录")
                    msg.setIcon(QtWidgets.QMessageBox.Information)
                    msg.setWindowFlags(QtCore.Qt.WindowStaysOnTopHint)
                    msg.exec_()
            
            # 第二步：获取场景中的材质和贴图
            self.status_bar.setText("正在获取场景中的材质...")
            materials = self._get_scene_materials()
            
            if not materials:
                self.status_bar.setText("未找到材质，无法继续扫描贴图")
                if not self.auto_run:  # 只在非自动运行模式下显示消息框
                    rt.messageBox("场景中未找到材质，无法扫描贴图。")
                return
                
            self.status_bar.setText(f"找到 {len(materials)} 个材质，正在扫描贴图...")
            
            # 创建进度对话框
            progress = ProgressDialog(self, "扫描贴图", len(materials))
            progress.show()
            
            texture_count = 0
            try:
                # 第三步：处理每个材质以查找贴图
                for i, material in enumerate(materials):
                    progress.set_value(i+1)
                    progress.set_label(f"正在扫描材质 {i+1} / {len(materials)}")
                    
                    try:
                        textures = self._get_material_textures(material)
                        
                        # 第四步：计算贴图哈希值并记录信息
                        for texture in textures:
                            try:
                                if texture and hasattr(texture, 'filename') and texture.filename:
                                    # 计算贴图文件的哈希值
                                    hash_value = self._calculate_file_hash(texture.filename)
                                    
                                    # 检查贴图是否被引用
                                    is_referenced = "是" if texture.filename else "否"
                                    
                                    # 获取当前名称
                                    current_name = os.path.basename(texture.filename)
                                    
                                    # 检查此贴图是否存在于导入的数据中
                                    if hash_value in existing_textures_dict:
                                        existing_data = existing_textures_dict[hash_value]
                                        # 保持原始名称不变，使用先前记录的原始名称
                                        original_name = existing_data.get("original", current_name)
                                        
                                        # 获取所有修改历史
                                        modification_history = {}
                                        for key, value in existing_data.items():
                                            if key.startswith("modified("):
                                                modification_history[key] = value
                                        
                                        # 如果当前名称与最后一次修改的名称不同，增加新的修改记录
                                        if modification_history and current_name != list(modification_history.values())[-1]:
                                            self.modification_count += 1
                                            modification_history[f"modified({self.modification_count})"] = current_name
                                        elif not modification_history:
                                            # 如果没有修改历史但有原始数据，添加第一个修改记录
                                            modification_history[f"modified(1)"] = current_name
                                    else:
                                        # 第一次看到这个贴图，当前名称就是原始名称
                                        original_name = current_name
                                        modification_history = {f"modified(1)": current_name}
                                    
                                    # 存储贴图对象引用以供以后使用
                                    self.texture_map_objects[hash_value] = texture
                                    
                                    # 添加到贴图数据中（如果尚未存在）
                                    if not any(item["hash"] == hash_value for item in self.texture_data):
                                        texture_info = {
                                            "hash": hash_value,
                                            "referenced": is_referenced,
                                            "original": original_name
                                        }
                                        # 添加所有修改历史
                                        texture_info.update(modification_history)
                                        self.texture_data.append(texture_info)
                                        texture_count += 1
                            except Exception as tex_err:
                                print(f"处理贴图时出错: {str(tex_err)}")
                                continue
                    except Exception as mat_err:
                        print(f"处理材质时出错: {str(mat_err)}")
                        continue
            finally:
                progress.close()
            
            # 查找重复贴图
            self.status_bar.setText("正在检查重复贴图...")
            self.duplicate_textures = self.find_duplicate_textures()
            
            # 更新表格列
            self._update_table_columns()
            
            # 第五步：将获取到的信息显示在表格中
            self.status_bar.setText("正在更新表格显示...")
            self.is_updating_table = True
            try:
                for item in self.texture_data:
                    self._add_row_to_table(item)
            finally:
                self.is_updating_table = False
            
            # 显示消息
            if len(self.texture_data) > 0:
                duplicate_msg = f"，其中包含 {len(self.duplicate_textures)} 个重复贴图" if self.duplicate_textures else ""
                status_msg = f"已找到 {len(self.texture_data)} 个贴图{duplicate_msg}"
                self.status_bar.setText(status_msg)
                if not self.auto_run:  # 只在非自动运行模式下显示消息框
                    rt.messageBox(f"共找到 {len(self.texture_data)} 个贴图{duplicate_msg}.")
            else:
                self.status_bar.setText("未找到贴图")
                if not self.auto_run:  # 只在非自动运行模式下显示消息框
                    rt.messageBox("场景中未找到贴图.")
        except Exception as main_err:
            error_msg = str(main_err)
            self.status_bar.setText(f"执行记录操作时出错: {error_msg}")
            if not self.auto_run:  # 只在非自动运行模式下显示消息框
                rt.messageBox(f"执行记录操作时出错: {error_msg}")
    
    def revert_to_selected(self):
        """
        撤回到选中名称
        按照流程图实现:
        1. 根据列表中选择的组不同撤回当前贴图的命名
        2. 更新对应材质球中贴图的索引
        """
        selected_rows = self.table.selectedIndexes()
        if not selected_rows:
            self.status_bar.setText("请先选择要撤回的贴图")
            rt.messageBox("请先选择要撤回的贴图.")
            return
            
        # Get the row of the first selected item
        selected_row = selected_rows[0].row()
        
        # Get hash value from the selected row
        hash_value = self.table.item(selected_row, 0).text()
        original_name = self.table.item(selected_row, 2).text()
        
        # Update status
        self.status_bar.setText(f"正在撤回贴图: {original_name}...")
        
        # Find the texture in our data
        if hash_value in self.texture_map_objects:
            texture = self.texture_map_objects[hash_value]
            
            if texture and hasattr(texture, 'filename'):
                # Get the directory of the current filename
                current_dir = os.path.dirname(texture.filename)
                new_path = os.path.join(current_dir, original_name)
                
                # Update the texture filename in 3ds Max
                try:
                    with rt.undo(True):
                        texture.filename = new_path
                    
                    # Update the table and data
                    self.is_updating_table = True
                    try:
                        for item in self.texture_data:
                            if item["hash"] == hash_value:
                                item["modified(1)"] = original_name
                        
                        is_duplicate = hash_value in self.duplicate_textures
                        self.table.item(selected_row, 3).setText(original_name)
                    finally:
                        self.is_updating_table = False
                    
                    self.status_bar.setText(f"已撤回到原始名称: {original_name}")
                    rt.messageBox("已撤回到原始名称: {}".format(original_name))
                except Exception as e:
                    error_msg = str(e)
                    self.status_bar.setText(f"撤回失败: {error_msg}")
                    rt.messageBox("撤回失败: {}".format(error_msg))
            else:
                self.status_bar.setText("无法获取贴图文件名")
                rt.messageBox("无法获取贴图文件名.")
        else:
            self.status_bar.setText("找不到选中的贴图，请先使用记录功能扫描场景")
            rt.messageBox("找不到选中的贴图，请先使用记录功能扫描场景.")
    
    def revert_all(self):
        """
        全部撤回到上一步命名
        按照流程图实现:
        1. 将场景中的全部贴图根据列表中的反向顺序进行回退命名
        """
        if not self.texture_data or not self.texture_map_objects:
            self.status_bar.setText("没有贴图记录可以撤回")
            rt.messageBox("没有贴图记录可以撤回.")
            return
        
        reply = QtWidgets.QMessageBox.question(
            self, "确认撤回", 
            "确定要将所有贴图撤回到原始名称吗？",
            QtWidgets.QMessageBox.Yes | QtWidgets.QMessageBox.No
        )
        
        if reply != QtWidgets.QMessageBox.Yes:
            return
        
        self.status_bar.setText("正在撤回所有贴图...")
            
        # Create progress dialog
        progress = ProgressDialog(self, "撤回贴图", len(self.texture_map_objects))
        progress.show()
        
        try:
            # 根据列表中的反向顺序进行回退 - 这里使用reversed()来实现反向处理
            texture_items = list(self.texture_map_objects.items())
            # 按照列表中的顺序反向处理，这样可以确保按照表中显示的相反顺序进行回退
            texture_items.reverse()
            
            with rt.undo(True):
                for i, (hash_value, texture) in enumerate(texture_items):
                    progress.set_value(i+1)
                    progress.set_label(f"正在处理贴图 {i+1} / {len(self.texture_map_objects)}")
                    
                    # Find the texture data
                    texture_info = next((item for item in self.texture_data if item["hash"] == hash_value), None)
                    
                    if texture_info and texture and hasattr(texture, 'filename'):
                        original_name = texture_info["original"]
                        current_dir = os.path.dirname(texture.filename)
                        new_path = os.path.join(current_dir, original_name)
                        
                        # Update the texture filename in 3ds Max
                        texture.filename = new_path
                        
                        # Update the data
                        texture_info["modified(1)"] = original_name
        except Exception as e:
            error_msg = str(e)
            self.status_bar.setText(f"全部撤回失败: {error_msg}")
            rt.messageBox("全部撤回失败: {}".format(error_msg))
            return
        finally:
            progress.close()
        
        # Update the table
        self.is_updating_table = True
        try:
            self.table.setRowCount(0)
            for item in self.texture_data:
                is_duplicate = item["hash"] in self.duplicate_textures
                self._add_row_to_table(
                    item["hash"],
                    item["referenced"],
                    item["original"],
                    item["modified(1)"],
                    is_duplicate
                )
        finally:
            self.is_updating_table = False
            
        self.status_bar.setText("已全部撤回到原始名称")
        rt.messageBox("已全部撤回到原始名称.")
    
    def import_records(self):
        """
        导入记录值
        按照流程图实现:
        1. 导入JSON数据，检验格式
        2. 对比导入的数据贴图是否存在于场景中使用
        3. 如果有则使用相应值
        4. 将数据显示在列表中
        """
        scene_file = rt.maxFilePath
        default_dir = os.path.dirname(scene_file) if scene_file else ""
        
        self.status_bar.setText("选择记录文件...")
        
        file_path, _ = QtWidgets.QFileDialog.getOpenFileName(
            self, "选择记录文件", default_dir, "JSON Files (*.json)"
        )
        
        if file_path:
            try:
                self.status_bar.setText(f"正在导入 {os.path.basename(file_path)}...")
                
                # 1. 检验JSON数据格式
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    
                    # 验证JSON格式
                    if not isinstance(data, list):
                        raise ValueError("JSON格式错误：应为列表")
                    
                    for item in data:
                        if not isinstance(item, dict):
                            raise ValueError("JSON格式错误：列表项应为字典")
                        if "hash" not in item or "original" not in item:
                            raise ValueError("JSON格式错误：缺少必要字段")
                    
                    self.status_bar.setText("JSON格式验证通过，正在应用...")
                except Exception as json_err:
                    raise ValueError(f"JSON数据格式错误: {str(json_err)}")
                
                # Clear existing data
                self.texture_data = []
                self.table.setRowCount(0)
                
                # Add imported data
                for item in data:
                    self.texture_data.append(item)
                
                # 2. 对比导入的数据贴图是否存在于场景中使用
                progress = ProgressDialog(self, "导入贴图记录", 2)
                progress.show()
                
                try:
                    progress.set_label("正在重新扫描场景贴图...")
                    progress.set_value(1)
                    
                    # Re-create the texture objects dictionary
                    self.texture_map_objects = {}
                    materials = self._get_scene_materials()
                    scene_textures = []
                    
                    for material in materials:
                        textures = self._get_material_textures(material)
                        
                        for texture in textures:
                            if texture and hasattr(texture, 'filename') and texture.filename:
                                hash_value = self._calculate_file_hash(texture.filename)
                                self.texture_map_objects[hash_value] = texture
                                scene_textures.append(hash_value)
                    
                    # 记录匹配情况
                    total_records = len(self.texture_data)
                    matched_records = sum(1 for item in self.texture_data if item["hash"] in scene_textures)
                    
                    progress.set_label("正在应用导入的贴图名称...")
                    progress.set_value(2)
                    
                    # 3. 如果有则使用相应值
                    with rt.undo(True):
                        for item in self.texture_data:
                            hash_value = item["hash"]
                            if hash_value in self.texture_map_objects:
                                texture = self.texture_map_objects[hash_value]
                                if texture and hasattr(texture, 'filename'):
                                    # Get current directory
                                    current_dir = os.path.dirname(texture.filename)
                                    # Get new filename
                                    modified_name = item.get("modified(1)", "")
                                    if modified_name:
                                        new_path = os.path.join(current_dir, modified_name)
                                        texture.filename = new_path
                finally:
                    progress.close()
                
                # Find duplicate textures
                self.duplicate_textures = self.find_duplicate_textures()
                
                # 4. 将数据显示在列表中
                self.is_updating_table = True
                try:
                    self.table.setRowCount(0)
                    for item in self.texture_data:
                        is_duplicate = item["hash"] in self.duplicate_textures
                        is_in_scene = item["hash"] in scene_textures
                        # 更新引用状态
                        if is_in_scene:
                            item["referenced"] = "是"
                        else:
                            item["referenced"] = "否"
                            
                        self._add_row_to_table(
                            item.get("hash", ""),
                            item.get("referenced", ""),
                            item.get("original", ""),
                            item.get("modified(1)", ""),
                            is_duplicate
                        )
                finally:
                    self.is_updating_table = False
                
                # 提供匹配统计
                match_info = f"(匹配: {matched_records}/{total_records})" if total_records > 0 else ""
                duplicate_msg = f"，其中包含 {len(self.duplicate_textures)} 个重复贴图" if self.duplicate_textures else ""
                self.status_bar.setText(f"成功导入 {len(data)} 条记录{match_info}{duplicate_msg}")
                rt.messageBox(f"成功导入 {len(data)} 条记录{match_info}{duplicate_msg}")
            except Exception as e:
                error_msg = str(e)
                self.status_bar.setText(f"导入失败: {error_msg}")
                rt.messageBox("导入失败: {}".format(error_msg))
        else:
            self.status_bar.setText("取消导入")
    
    def export_records(self):
        """
        导出记录值
        按照流程图实现:
        1. 将列表中的记录的数据导出为JSON文件
        2. 默认保存在场景文件根目录下
        """
        if not self.texture_data:
            self.status_bar.setText("没有贴图记录可以导出")
            rt.messageBox("没有贴图记录可以导出.")
            return
            
        # 获取场景文件根目录
        scene_file = rt.maxFilePath
        default_dir = os.path.dirname(scene_file) if scene_file else ""
        default_name = os.path.splitext(os.path.basename(scene_file))[0] + "_textures.json" if scene_file else "texture_records.json"
        
        self.status_bar.setText("选择保存位置...")
        
        # 设置默认保存在场景文件根目录下
        default_path = os.path.join(default_dir, default_name)
        file_path, _ = QtWidgets.QFileDialog.getSaveFileName(
            self, "保存记录文件", default_path, "JSON Files (*.json)"
        )
        
        if file_path:
            try:
                self.status_bar.setText(f"正在导出记录到 {os.path.basename(file_path)}...")
                
                # 准备导出数据 - 符合所需格式
                export_data = []
                for item in self.texture_data:
                    export_item = {
                        "hash": item["hash"],
                        "referenced": item["referenced"],
                        "original": item["original"],
                        "modified(1)": item["modified(1)"]
                    }
                    # 添加是否为重复贴图的标记
                    export_item["is_duplicate"] = item["hash"] in self.duplicate_textures
                    export_data.append(export_item)
                
                # 生成标准格式的JSON
                with open(file_path, 'w', encoding='utf-8') as f:
                    json.dump(export_data, f, ensure_ascii=False, indent=2)
                
                # 显示成功消息，包含文件路径
                self.status_bar.setText(f"成功导出记录到 {os.path.basename(file_path)}")
                rt.messageBox("成功导出记录到 {}.".format(file_path))
            except Exception as e:
                error_msg = str(e)
                self.status_bar.setText(f"导出失败: {error_msg}")
                rt.messageBox("导出失败: {}".format(error_msg))
        else:
            self.status_bar.setText("取消导出")
    
    def _find_existing_json_record(self):
        """
        从场景文件根目录中尝试获取JSON文件
        这是按照流程图进行的实现:
        1. 从场景文件根目录中尝试获取json文件
        2. 如果获取成功，则使用JSON文件中的贴图信息值
        3. 如果未获取到JSON文件，则使用标准方式获取贴图信息
        """
        scene_file = rt.maxFilePath
        if not scene_file:
            self.status_bar.setText("未找到场景文件，无法获取JSON记录")
            return None
        
        scene_dir = os.path.dirname(scene_file)
        scene_name = os.path.splitext(os.path.basename(scene_file))[0]
        
        # 首先检查与场景文件同名的JSON记录
        json_path = os.path.join(scene_dir, scene_name + "_textures.json")
        
        if os.path.exists(json_path):
            try:
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                self.status_bar.setText(f"成功获取JSON记录: {os.path.basename(json_path)}")
                return data
            except Exception as e:
                self.status_bar.setText(f"读取JSON记录失败: {str(e)}")
                pass
        
        # 如果未找到同名文件，检查目录中的任何JSON文件
        found_files = []
        for file in os.listdir(scene_dir):
            if file.endswith(".json"):
                json_path = os.path.join(scene_dir, file)
                try:
                    with open(json_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        # 检查是否是我们的格式
                        if isinstance(data, list) and len(data) > 0 and "hash" in data[0]:
                            found_files.append((json_path, data))
                except:
                    continue
        
        # 如果找到多个文件，使用最新的一个
        if found_files:
            found_files.sort(key=lambda x: os.path.getmtime(x[0]), reverse=True)
            newest_file, data = found_files[0]
            self.status_bar.setText(f"成功获取最新JSON记录: {os.path.basename(newest_file)}")
            return data
        
        self.status_bar.setText("未找到JSON记录，将使用标准方式获取贴图信息")
        return None
    
    def _add_row_to_table(self, hash_value, is_referenced, original_name, modified_name, is_duplicate=False):
        """Add a row to the table with the given texture information"""
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        # Add items to row
        hash_item = QtWidgets.QTableWidgetItem(hash_value)
        hash_item.setFlags(hash_item.flags() & ~QtCore.Qt.ItemIsEditable)  # Make non-editable
        hash_item.setToolTip(hash_value)  # Add tooltip for long hash values
        if is_duplicate:
            hash_item.setBackground(QtGui.QColor(WARNING_COLOR))
            hash_item.setToolTip(hash_value + " - 重复贴图")
        self.table.setItem(row, 0, hash_item)
        
        # Referenced indicator with icon
        ref_item = QtWidgets.QTableWidgetItem(is_referenced)
        ref_item.setFlags(ref_item.flags() & ~QtCore.Qt.ItemIsEditable)  # Make non-editable
        ref_item.setTextAlignment(QtCore.Qt.AlignCenter)  # Center align text
        ref_item.setToolTip("贴图是否被引用" if is_referenced == "是" else "贴图未被引用")
        self.table.setItem(row, 1, ref_item)
        
        # Original name with tooltip
        orig_item = QtWidgets.QTableWidgetItem(original_name)
        orig_item.setFlags(orig_item.flags() & ~QtCore.Qt.ItemIsEditable)  # Make non-editable
        orig_item.setToolTip(original_name)
        if is_duplicate:
            orig_item.setForeground(QtGui.QColor(WARNING_COLOR))
        self.table.setItem(row, 2, orig_item)
        
        # Modified name - editable
        mod_item = QtWidgets.QTableWidgetItem(modified_name)
        mod_item.setToolTip("双击编辑名称")
        if is_duplicate:
            mod_item.setForeground(QtGui.QColor(WARNING_COLOR))
        self.table.setItem(row, 3, mod_item)
    
    def _get_scene_materials(self):
        """Get all materials in the scene"""
        materials = []
        
        # Get all scene nodes
        for obj in rt.objects:
            if hasattr(obj, 'material') and obj.material:
                materials.append(obj.material)
        
        # Also check the material library
        try:
            # 在3ds Max中材质编辑器通常有24个槽位，但需要安全访问
            # 检查meditMaterials是否存在和是否有count属性
            if hasattr(rt, 'meditMaterials'):
                material_count = 24  # 默认材质槽数量
                
                # 尝试获取实际槽位数量
                if hasattr(rt.meditMaterials, 'count'):
                    try:
                        material_count = int(rt.meditMaterials.count)
                    except:
                        pass  # 使用默认值
                
                # 安全地遍历材质槽
                for i in range(1, material_count + 1):
                    try:
                        material = rt.meditMaterials[i]
                        if material:
                            materials.append(material)
                    except:
                        # 忽略索引错误，继续处理
                        continue
        except:
            # 如果访问meditMaterials时出错，忽略并继续
            pass
        
        return materials
    
    def _get_material_textures(self, material):
        """Get all textures from a material recursively"""
        textures = []
        
        if not material:
            return textures
            
        try:
            material_class = str(rt.classOf(material))
            
            # Check if it's a standard material
            if rt.classOf(material) == rt.StandardMaterial:
                # Check common map slots
                map_slots = ['diffuseMap', 'specularMap', 'glossinessMap', 'bumpMap', 
                            'reflectionMap', 'refractionMap', 'displacementMap', 
                            'selfIllumMap', 'opacityMap', 'filterMap']
                            
                for slot in map_slots:
                    try:
                        if hasattr(material, slot):
                            tex_map = getattr(material, slot)
                            if tex_map:
                                textures.append(tex_map)
                    except:
                        continue
            
            # Check for VRay materials
            elif "VRay" in material_class:
                # VRay material properties vary, we'll check common ones
                vray_slots = ['texmap_diffuse', 'texmap_reflect', 'texmap_bump', 'texmap_opacity']
                for slot in vray_slots:
                    try:
                        if hasattr(material, slot) and getattr(material, slot):
                            textures.append(getattr(material, slot))
                    except:
                        continue
            
            # Check if it's a multi/sub-material
            elif rt.classOf(material) == rt.MultiMaterial:
                try:
                    num_subs = material.numSubs
                    for i in range(1, num_subs + 1):
                        try:
                            sub_mat = material[i]
                            if sub_mat:
                                sub_textures = self._get_material_textures(sub_mat)
                                textures.extend(sub_textures)
                        except:
                            continue
                except:
                    pass
            
            # For bitmap textures, add them directly
            elif rt.classOf(material) == rt.Bitmaptexture:
                textures.append(material)
            
            # Handle map layers (composite maps)
            elif rt.classOf(material) == rt.CompositeTexturemap:
                try:
                    # Get number of subtextures in the composite
                    num_maps = rt.getNumSubTexmaps(material)
                    for i in range(1, num_maps + 1):
                        try:
                            sub_tex = rt.getSubTexmap(material, i)
                            if sub_tex:
                                sub_textures = self._get_material_textures(sub_tex)
                                textures.extend(sub_textures)
                        except:
                            continue
                except:
                    pass
            
            # 尝试处理其他类型的材质
            else:
                # 通用方法：尝试获取所有可能的贴图属性
                try:
                    # 尝试使用getNumSubTexmaps/getSubTexmap方法
                    if hasattr(rt, 'getNumSubTexmaps') and hasattr(rt, 'getSubTexmap'):
                        try:
                            num_maps = rt.getNumSubTexmaps(material)
                            for i in range(1, num_maps + 1):
                                try:
                                    sub_tex = rt.getSubTexmap(material, i)
                                    if sub_tex:
                                        sub_textures = self._get_material_textures(sub_tex)
                                        textures.extend(sub_textures)
                                except:
                                    continue
                        except:
                            pass
                except:
                    pass
                
        except Exception as e:
            print(f"处理材质 {material} 时出错: {str(e)}")
            # 出错时继续，返回已找到的贴图
            
        return textures
    
    def _calculate_file_hash(self, file_path):
        """Calculate MD5 hash for a file"""
        try:
            if os.path.exists(file_path):
                md5_hash = hashlib.md5()
                with open(file_path, "rb") as f:
                    # Read file in chunks to avoid memory issues with large files
                    for chunk in iter(lambda: f.read(4096), b""):
                        md5_hash.update(chunk)
                return md5_hash.hexdigest()
            else:
                return "File not found: " + file_path
        except Exception as e:
            return "Error: " + str(e)

    def _update_table_columns(self):
        """更新表格列以显示所有修改历史"""
        # 获取所有可能的修改列
        modification_columns = set()
        for item in self.texture_data:
            for key in item.keys():
                if key.startswith("modified("):
                    modification_columns.add(key)
        
        # 按修改序号排序
        modification_columns = sorted(list(modification_columns), 
                                    key=lambda x: int(x.split("(")[1].split(")")[0]))
        
        # 设置新的列数
        new_column_count = 3 + len(modification_columns)  # 3个基础列 + 修改历史列
        self.table.setColumnCount(new_column_count)
        
        # 设置表头
        headers = ["哈希值", "贴图是否引用", "原始贴图名称"]
        headers.extend(modification_columns)
        self.table.setHorizontalHeaderLabels(headers)

    def _add_row_to_table(self, item):
        """Add a row to the table with the given texture information"""
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        # Add items to row
        hash_item = QtWidgets.QTableWidgetItem(item["hash"])
        hash_item.setFlags(hash_item.flags() & ~QtCore.Qt.ItemIsEditable)  # Make non-editable
        hash_item.setToolTip(item["hash"])  # Add tooltip for long hash values
        if item["hash"] in self.duplicate_textures:
            hash_item.setBackground(QtGui.QColor(WARNING_COLOR))
            hash_item.setToolTip(item["hash"] + " - 重复贴图")
        self.table.setItem(row, 0, hash_item)
        
        # Referenced indicator with icon
        ref_item = QtWidgets.QTableWidgetItem(item["referenced"])
        ref_item.setFlags(ref_item.flags() & ~QtCore.Qt.ItemIsEditable)  # Make non-editable
        ref_item.setTextAlignment(QtCore.Qt.AlignCenter)  # Center align text
        ref_item.setToolTip("贴图是否被引用" if item["referenced"] == "是" else "贴图未被引用")
        self.table.setItem(row, 1, ref_item)
        
        # Original name with tooltip
        orig_item = QtWidgets.QTableWidgetItem(item["original"])
        orig_item.setFlags(orig_item.flags() & ~QtCore.Qt.ItemIsEditable)  # Make non-editable
        orig_item.setToolTip(item["original"])
        if item["hash"] in self.duplicate_textures:
            orig_item.setForeground(QtGui.QColor(WARNING_COLOR))
        self.table.setItem(row, 2, orig_item)
        
        # Add modification history columns
        for i, mod_key in enumerate(sorted([k for k in item.keys() if k.startswith("modified(")], 
                                         key=lambda x: int(x.split("(")[1].split(")")[0]))):
            mod_item = QtWidgets.QTableWidgetItem(item[mod_key])
            mod_item.setToolTip("双击编辑名称")
            if item["hash"] in self.duplicate_textures:
                mod_item.setForeground(QtGui.QColor(WARNING_COLOR))
            self.table.setItem(row, 3 + i, mod_item)

def run():
    """
    运行脚本并创建对话框
    按照流程图顺序：
    1. 脚本启动运行
    2. 自动执行记录功能
    """
    # 创建并显示对话框
    dialog = TextureManager()
    dialog.show()
    
    # 短暂延迟后自动执行记录功能，确保界面已完全加载
    # 传递auto_run=True参数，表示这是自动运行，不需要弹窗确认
    QtCore.QTimer.singleShot(500, lambda: dialog.record_textures(auto_run=True))
    
    # 返回对话框以防止被垃圾回收
    return dialog

# Run the script
if __name__ == "__main__":
    dialog = run() 