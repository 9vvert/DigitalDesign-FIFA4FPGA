// 场地约束
// 规定了重要边界的位置、游戏开始的默认站位

package field_package;
    parameter PLAYER0_X = 450;
    parameter PLAYER0_Y = 335;
    parameter PLAYER1_X = 375;
    parameter PLAYER1_Y = 490;
    parameter PLAYER2_X = 375;
    parameter PLAYER2_Y = 170;
    parameter PLAYER3_X = 200;
    parameter PLAYER3_Y = 335;
    parameter PLAYER4_X = 90;
    parameter PLAYER4_Y = 335;

    parameter PLAYER5_X = 815;
    parameter PLAYER5_Y = 335;
    parameter PLAYER6_X = 890;
    parameter PLAYER6_Y = 490;
    parameter PLAYER7_X = 890;
    parameter PLAYER7_Y = 170;
    parameter PLAYER8_X = 1070;
    parameter PLAYER8_Y = 335;
    parameter PLAYER9_X = 1170;
    parameter PLAYER9_Y = 335;
    // 球的位置，轮流
    parameter BALL_Y = 335;
    parameter BALL_X1 = 560;
    parameter BALL_X2 = 710;

    // 基本场地，近似约束
    parameter LEFT_X = 65;
    parameter RIGHT_X = 1200;
    parameter TOP_Y = 575;
    parameter BOTTOM_Y = 60;
    parameter MID_X = 635;
    
    // 球网，用于约束足球和得分判定
    parameter LEFT_NET_X1 = 20;
    parameter LEFT_NET_X2 = 65;
    parameter LEFT_NET_Y1 = 270;
    parameter LEFT_NET_Y2 = 400;
    parameter RIGHT_NET_X1 = 1200;
    parameter RIGHT_NET_X2 = 1255;
    parameter RIGHT_NET_Y1 = 270;
    parameter RIGHT_NET_Y2 = 400;

    //门将区
    parameter LEFT_KEEPER_X1 = 65;
    parameter LEFT_KEEPER_X2 = 120;
    parameter LEFT_KEEPER_Y1 = 235;
    parameter LEFT_KEEPER_Y2 = 420;
    parameter RIGHT_KEEPER_X1 = 1140;
    parameter RIGHT_KEEPER_X2 = 1215;
    parameter RIGHT_KEEPER_Y1 = 235;
    parameter RIGHT_KEEPER_Y2 = 420;

    //罚球区，用于作为进攻标记
    parameter LEFT_ATTACK_X1 = 65;
    parameter LEFT_ATTACK_X2 = 270;
    parameter LEFT_ATTACK_Y1 = 170;
    parameter LEFT_ATTACK_Y2 = 490;
    parameter RIGHT_ATTACK_X1 = 1000;
    parameter RIGHT_ATTACK_X2 = 1215;
    parameter RIGHT_ATTACK_Y1 = 170;
    parameter RIGHT_ATTACK_Y2 = 490;
endpackage

