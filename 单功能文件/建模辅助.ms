try(destroyDialog myDialog) catch()

rollout myDialog "建模辅助" width:200 height:300
(
    group "创建基本体"
    (
        label lbl1 "底商高度" align:#left
        editText et1 "" width:100
        label lbl2 "楼层" align:#right offset:[-50,0]
        editText et2 "" width:100
        label lbl3 "层高" align:#right offset:[-50,0]
        editText et3 "" width:100
    )
    
    group "女儿墙创建"
    (
        label lbl4 "厚度" align:#left
        editText et4 "" width:100
        label lbl5 "高度" align:#right offset:[-50,0]
        editText et5 "" width:100
    )
)

createDialog myDialog

