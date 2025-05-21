package type_declare;
    typedef struct packed {
        logic [2:0] render_type;       //要渲染的对象类型（填补背景：0 | A方人物：1 | B方人物：2 | 足球：3 | 辅助块：4）
        logic [11:0] h_pos;
        logic [11:0] v_pos;     
        logic [7:0] angle;      //朝向的目标，对于人物和辅助块都有用
        logic [3:0] stat;       //物体的状态，对于人来说是action，对于足球来说是在几个图层之间进行切换
        logic [11:0] width;      //对应图片的宽度
        logic [11:0] height;     //对应图片的高度
    } Render_Param_t;        
    parameter TEST_DEBUG = 1;
    parameter TEST_WIDTH = 12;
    parameter TEST_HSIZE = 256;    // 有效显示宽度
    parameter TEST_HFP   = 272;    // 前肩: HSIZE + 16
    parameter TEST_HSP   = 280;    // 同步脉冲开始: HFP + 8
    parameter TEST_HMAX  = 296;    // 总行长: HSP + 16
    parameter TEST_VSIZE = 144;    // 有效显示高度
    parameter TEST_VFP   = 148;    // 前肩: VSIZE + 4
    parameter TEST_VSP   = 150;    // 同步脉冲开始: VFP + 2
    parameter TEST_VMAX  = 154;    // 总场高: VSP + 4
    parameter TEST_HSPP  = 1;
    parameter TEST_VSPP  = 1;
endpackage

