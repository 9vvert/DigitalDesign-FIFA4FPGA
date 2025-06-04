package ai_package;
    parameter LEFT_GOAL_X = 64;
    parameter LEFT_GOAL_TOP_Y= 400;
    parameter LEFT_GOAL_BOTTOM_Y= 270;
    parameter RIGHT_GOAL_X = 1200;
    parameter RIGHT_GOAL_TOP_Y= 400;
    parameter RIGHT_GOAL_BOTTOM_Y= 270;

    typedef enum {
        /*********泛用决策******/
        C_DISABLE,    //被操控者，无法被AI管理器分配决策
        C_IDLE,
        /*********持球方决策******/
        A_FORWARD,      // 在侧面辅助，提供射门机会(和AreaIntercept类似)
        A_DEFEND,       // 进攻方，和对手最后的球员在水平方向上的距离不能超过150，作为被抢球后的保底
        /*********非持球方决策******/
        // 一人抢球，剩下的2个人防守拦截。具体拦截的参数需要指定
        D_TACKLE,       //尝试抢球，抢断或者铲球
        D_FORWARD,
        D_AREA_INTERCEPT,       //面拦截
        D_KEEPER               //门将
    } Decision_t;

endpackage

