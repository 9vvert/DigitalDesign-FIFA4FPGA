package type_declare;
    typedef struct packed {
        logic enable;           //渲染使能
        logic [11:0] hpos;
        logic [11:0] vpos;  
        logic [15:0] start_sector;  //资源所在的起始扇区(对于背景类型无效)   
        logic [11:0] render_priority;       //渲染优先级
        // 大小固定为32*32，不用再增加参数
    } Render_Param_t;
    parameter TEST_DEBUG = 0;
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


    //球员信息
    typedef struct packed {
        logic [11:0] master_x;
        logic [11:0] master_y;
        logic [11:0] master_height;
        logic [7:0] master_speed;       // 为了渲染足球动画
    } ConstrainedInit;

    typedef struct packed {
        logic [7:0] init_speed;
        logic [7:0] init_angle;
        logic [7:0] init_vertical_speed;
        logic init_vertical_signal;
    } FreeInit;
    
    typedef struct packed {
        logic selected;
        logic target;           //预切换球员
        logic [2:0] index;      //球员编号
        logic [11:0] x;
        logic [11:0] y;
        //[TODO] 暂时不给人物增加跳跃功能
        logic [7:0] angle;  
        logic [7:0] speed;
        logic [3:0] anim_stat;      // 同一个方向上有5个stat； [TODO]后续渲染的时候要注意对接
    } PlayerInfo;
    typedef struct packed {
        logic [11:0] x;
        logic [11:0] y;
        logic [11:0] z;
        logic [7:0] angle;
        logic [7:0] speed;
        logic vertical_signal;
        logic [7:0] vertical_speed;
        logic [3:0] anim_stat;
    } BallInfo;
    typedef struct packed {     //控制加速度和角速度，足以改变人物的运动
        logic A_enable;
        logic A_signal;
        logic W_enable;
        logic W_signal;
    } MoveControl;
endpackage

