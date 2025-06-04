/******** simulator **********/
// 输入决策和外部作用力，产生相应的模拟值
import type_declare::*;
import ai_package::*;
import field_package::*;
module simulator
#(parameter SELF_INDEX=0, TEAM=0)
(
    input simulator_game_clk,       // 游戏时钟
    input rst,
    //信息
    input PlayerInfo player_info[9:0],
    input BallInfo ball_info,
    input [3:0] hold_index,
    //输入的决策 (外部只是分发决策，具体的向量分配、计算都在内部完成)
    input Decision_t Decision,
    //输入的参数
    input [1:0] forward_mode,
    input [7:0] area_angle1,
    input [7:0] area_angle2,
    //输出模拟值
    output reg [7:0] ai_left_angle,
    output reg [7:0] ai_right_angle,
    output reg [7:0] ai_action_cmd

);
    wire ai_tackle;
    wire ai_sprint;     //冲刺
    wire enable_sprint;
    assign ai_right_angle = 'hFF;
    assign ai_action_cmd[7:0] = {1'b0,1'b0,1'b0,ai_tackle,1'b0,1'b0,1'b0,ai_sprint};

    /*********** 方向模拟  **********/
    //输入向量即可工作
    reg [11:0] x_pos;
    reg [11:0] x_neg;
    reg [11:0] y_pos;
    reg [11:0] y_neg;       // [TODO]在后续计算
    simu_move u_simu_move(
        .simulator_game_clk(simulator_game_clk),
        .rst(rst),
        .curr_angle(player_info[SELF_INDEX].angle), 
        .x_pos(x_pos),
        .x_neg(x_neg),
        .y_pos(y_pos),
        .y_neg(y_neg),
        .enable_sprint(enable_sprint),
        .simu_left_angle(ai_left_angle),
        .simu_sprint(ai_sprint)
    );    
    wire PlayerInfo self_info;
    assign self_info = player_info[SELF_INDEX];     // 固定
    PlayerInfo holder_info;

    always@(posedge simulator_game_clk)begin
        holder_info <= player_info[hold_index];
    end
    /*********** 模拟环境力场 ******/
    wire [2:0] force_level;
    wire [11:0] env_x_pos;
    wire [11:0] env_x_neg;
    wire [11:0] env_y_pos;
    wire [11:0] env_y_neg;
    simu_env_force #(.TEAM(TEAM))u_simu_env_force(
        .simulator_game_clk(simulator_game_clk),
        .rst(rst),
        //信息
        .force_level(force_level),
        .self_info(self_info),
        .player_info(player_info),      
        //输出模拟值
        .env_x_pos(env_x_pos),
        .env_x_neg(env_x_neg),
        .env_y_pos(env_y_pos),
        .env_y_neg(env_y_neg)
    );


    /***********决策模拟器*********/
    // DEFEND
    wire [11:0] defend_x_pos;
    wire [11:0] defend_x_neg;
    wire [11:0] defend_y_pos;
    wire [11:0] defend_y_neg;
    wire [2:0] defend_force_level;    
    wire defend_sprint_enable;
    a_defend #(.TEAM(TEAM))u_a_defend(  
        .self_info(self_info),
        .arival_info1( (TEAM==0) ? player_info[5] : player_info[0]),
        .arival_info2( (TEAM==0) ? player_info[6] : player_info[1]),
        .arival_info3( (TEAM==0) ? player_info[7] : player_info[2]),
        .arival_info4( (TEAM==0) ? player_info[8] : player_info[3]),
        .sprint_enable(defend_sprint_enable),
        .force_level(defend_force_level),
        .defend_x_pos(defend_x_pos),
        .defend_x_neg(defend_x_neg),
        .defend_y_pos(defend_y_pos),
        .defend_y_neg(defend_y_neg)
    );
    // FORWARD
    wire [11:0] forward_x_pos;
    wire [11:0] forward_x_neg;
    wire [11:0] forward_y_pos;
    wire [11:0] forward_y_neg;
    wire [2:0] forward_force_level;       // 外界的受排斥等级 这种情况下应该为2级
    wire forward_sprint_enable;       //是否允许冲刺
    a_forward #(.TEAM(TEAM))u_a_forward(
        .self_info(self_info),
        .holder_info(holder_info),
        .forward_mode(forward_mode),
        .sprint_enable(forward_sprint_enable),
        .force_level(forward_force_level),
        .forward_x_pos(forward_x_pos),
        .forward_x_neg(forward_x_neg),
        .forward_y_pos(forward_y_pos),
        .forward_y_neg(forward_y_neg)
    );
    // AREA_INTERCEPT
    wire [11:0] area_intercept_x_pos;
    wire [11:0] area_intercept_x_neg;
    wire [11:0] area_intercept_y_pos;
    wire [11:0] area_intercept_y_neg;
    wire [2:0] area_intercept_force_level;       //斥力等级
    wire area_intercept_enable_sprint;           //是否允许冲刺
    area_intercept u_area_intercept(
        .self_info(self_info),
        // 从P1到P2
        .x1(holder_info.x),    //持球人
        .y1(holder_info.y),                 //[TODO]如果没有持球人，是否可能出现不稳定的信号？
        .ang1(area_angle1),
        .ang2(area_angle2),
        //
        .force_level(area_intercept_force_level),
        //
        .enable_sprint(area_intercept_enable_sprint),
        .area_intercept_x_pos(area_intercept_x_pos),     //向目标牵引
        .area_intercept_x_neg(area_intercept_x_neg),
        .area_intercept_y_pos(area_intercept_y_pos),
        .area_intercept_y_neg(area_intercept_y_neg)
    );

    // TACKLE
    wire [11:0] tackle_x_pos;
    wire [11:0] tackle_x_neg;
    wire [11:0] tackle_y_pos;
    wire [11:0] tackle_y_neg;
    wire [2:0] tackle_force_level;       //斥力等级
    wire tackle_enable_sprint;           //是否允许冲刺
    wire tackle_tackle;            //是否进行铲球       //[TODO]对接外部数据
    d_tackle u_d_tackle(
        .self_info(self_info),
        .ball_info(ball_info),
        //
        .force_level(tackle_force_level),       //斥力等级
        //
        .enable_sprint(tackle_enable_sprint),           //是否允许冲刺
        .tackle_x_pos(tackle_x_pos),     //向目标牵引
        .tackle_x_neg(tackle_x_neg),
        .tackle_y_pos(tackle_y_pos),
        .tackle_y_neg(tackle_y_neg),
        .tackle(tackle_tackle)
    );


    /***********决策仲裁器 *********/
    reg  [11:0] decision_x_pos;
    reg  [11:0] decision_x_neg;
    reg  [11:0] decision_y_pos;
    reg  [11:0] decision_y_neg;
    reg [5:0] simulator_stat;
    always@(posedge simulator_game_clk)begin
        if(rst)begin
            simulator_stat <=C_IDLE;
        end else begin
            simulator_stat <= Decision;  // 外部的决策
        end
    end
    /****** 向量叠加  ********/
    always@(posedge simulator_game_clk)begin
        if(rst)begin
            x_pos <= 0;
            x_neg <= 0;
            y_pos <= 0;
            y_neg <= 0;
        end else begin
            // 向量叠加
            x_pos <= env_x_pos + decision_x_pos;
            x_neg <= env_x_neg + decision_x_neg;
            y_pos <= env_y_pos + decision_y_pos;
            y_neg <= env_y_neg + decision_y_neg;
        end
    end

    /*********** 信号仲裁 *********/
    assign force_level = (simulator_stat == C_DISABLE) ? 0 :
                         (simulator_stat == C_IDLE) ? 1 : 
                         (simulator_stat == A_DEFEND) ? defend_force_level :
                         (simulator_stat == A_FORWARD) ? forward_force_level :
                         (simulator_stat == D_TACKLE) ? tackle_force_level :
                         (simulator_stat == D_AREA_INTERCEPT) ? area_intercept_force_level :
                         0;
    assign enable_sprint = (simulator_stat == A_FORWARD) ? forward_sprint_enable :
                           (simulator_stat == D_TACKLE) ? tackle_enable_sprint :
                           (simulator_stat == D_AREA_INTERCEPT) ? area_intercept_enable_sprint :
                           0;
    assign ai_tackle = (simulator_stat == D_TACKLE) ? tackle_tackle : 0;

    assign decision_x_pos = (simulator_stat == C_DISABLE) ? 0 :
                            (simulator_stat == C_IDLE) ? 0 :
                            (simulator_stat == A_DEFEND) ? defend_x_pos :
                            (simulator_stat == A_FORWARD) ? forward_x_pos :
                            (simulator_stat == D_TACKLE) ? tackle_x_pos :
                            (simulator_stat == D_AREA_INTERCEPT) ? area_intercept_x_pos :
                            0;
    assign decision_x_neg = (simulator_stat == C_DISABLE) ? 0 :
                            (simulator_stat == C_IDLE) ? 0 :
                            (simulator_stat == A_DEFEND) ? defend_x_neg :
                            (simulator_stat == A_FORWARD) ? forward_x_neg :
                            (simulator_stat == D_TACKLE) ? tackle_x_neg :
                            (simulator_stat == D_AREA_INTERCEPT) ? area_intercept_x_neg :
                            0;
    assign decision_y_pos = (simulator_stat == C_DISABLE) ? 0 :
                            (simulator_stat == C_IDLE) ? 0 :
                            (simulator_stat == A_DEFEND) ? defend_y_pos :
                            (simulator_stat == A_FORWARD) ? forward_y_pos :
                            (simulator_stat == D_TACKLE) ? tackle_y_pos :
                            (simulator_stat == D_AREA_INTERCEPT) ? area_intercept_y_pos :
                            0;
    assign decision_y_neg = (simulator_stat == C_DISABLE) ? 0 :
                            (simulator_stat == C_IDLE) ? 0 :
                            (simulator_stat == A_FORWARD) ? forward_y_neg :
                            (simulator_stat == A_DEFEND) ? defend_y_neg :
                            (simulator_stat == D_TACKLE) ? tackle_y_neg :
                            (simulator_stat == D_AREA_INTERCEPT) ? area_intercept_y_neg :
                            0;
endmodule