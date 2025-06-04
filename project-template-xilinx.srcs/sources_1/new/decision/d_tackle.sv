// 尝试抢球，最后可能使用直抢或者铲球
// 模块作用：描述了处于tackle状态的时候可以怎么做
// 外界的simu_move相当于HFSM中的Move_FSM，
module d_tackle
// 这里的力应该设置的大一些，否则可能因为球靠近墙壁而无法捡球
#(parameter FOLLOW_FORCE=20)        // 目标的“吸引力”
(
    input PlayerInfo self_info,
    input BallInfo ball_info,
    //
    output wire [2:0] force_level,       //斥力等级
    //
    output reg enable_sprint,           //是否允许冲刺
    output reg [11:0] tackle_x_pos,     //向目标牵引
    output reg [11:0] tackle_x_neg,
    output reg [11:0] tackle_y_pos,
    output reg [11:0] tackle_y_neg,
    // cmd
    output reg tackle
);
    import LineLib::*;
    import AngleLib::*;
    import TrianglevalLib::*;
    
    assign force_level = 2; //因为是要去抢别人，所以轻微排斥

    logic [11:0] rel_dis;
    logic [7:0] rel_angle;
    
    //[TODO]检查是否覆盖了所有情况，防止出现锁存器
    always_comb begin
        rel_angle = vec2angle(self_info.x, self_info.y, ball_info.x, ball_info.y);
        rel_dis = distance(self_info.x, self_info.y, ball_info.x, ball_info.y);
        if(rel_dis >= 22500)begin

            tackle=0;
            enable_sprint=1;            // 距离远，允许冲刺
        end else if(rel_dis >= 2500)begin
            tackle=0;
            enable_sprint=0;    //禁止冲刺
        end else begin
            // 这个距离可以进行抢断，暂时不考虑铲球
            tackle=1;
            enable_sprint=0;
        end
        //

        if(rel_angle < 8'd18) begin
            tackle_x_pos = FOLLOW_FORCE*sin(rel_angle);
            tackle_x_neg = 0;
            tackle_y_pos = FOLLOW_FORCE*cos(rel_angle);
            tackle_y_neg = 0;
        end else if(rel_angle < 8'd36) begin
            tackle_x_pos = FOLLOW_FORCE*cos(rel_angle - 8'd18);
            tackle_x_neg = 0;
            tackle_y_pos = 0;
            tackle_y_neg = FOLLOW_FORCE*sin(rel_angle - 8'd18);
        end else if(rel_angle < 8'd54) begin
            tackle_x_pos = 0;
            tackle_x_neg = FOLLOW_FORCE*sin(rel_angle - 8'd36);
            tackle_y_pos = 0;
            tackle_y_neg = FOLLOW_FORCE*cos(rel_angle - 8'd36);
        end else begin
            tackle_x_pos = 0;
            tackle_x_neg = FOLLOW_FORCE*cos(rel_angle - 8'd54);
            tackle_y_pos = FOLLOW_FORCE*sin(rel_angle - 8'd54);
            tackle_y_neg = 0;
        end
    end

endmodule