// 上层的决策管理，仅仅是为了分配决策
import ai_package::*;
module ai_controller
#(parameter TEAM=0)         // 队伍分为 0, 1 
(
    input ai_game_clk,
    input rst,
    input [3:0]hold_index,  // 持球者,范围0-9
    input [3:0]selected_index1, 
    input [3:0]selected_index2, 
    input PlayerInfo player_info[9:0],
    input BallInfo ball_info,
    output [7:0] ai_left_angle[9:0],
    output [7:0] ai_right_angle[9:0],
    output [7:0] ai_action_cmd[9:0]
);
    Decision_t decision_grp1[4:0];
    wire [7:0] area_angle1_1, area_angle1_2;
    wire [1:0] forward_mode1[3:0];
    decision_tree #(.TEAM(0))u_decision_tree1
    (
        .ai_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .selected_index(selected_index1),
        .player_info(player_info),
        .ball_info(ball_info),
        .forward_mode(forward_mode1),
        .decision(decision_grp1),
        .area_angle1(area_angle1_1),
        .area_angle2(area_angle1_2)
    );
    Decision_t decision_grp2[4:0];
    wire [7:0] area_angle2_1, area_angle2_2;
    wire [1:0] forward_mode2[3:0];
    decision_tree #(.TEAM(1))u_decision_tree2
    (
        .ai_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .selected_index(selected_index2),
        .player_info(player_info),
        .ball_info(ball_info),
        .forward_mode(forward_mode2),
        .decision(decision_grp2),
        .area_angle1(area_angle2_1),
        .area_angle2(area_angle2_2)
    );

    /************ 模拟器  ************/
    simulator #(.TEAM(0), .SELF_INDEX(0)) u_simulator0(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle1_1),
        .area_angle2(area_angle1_2),
        .forward_mode(forward_mode1[0]),
        .Decision(decision_grp1[0]),
        .ai_left_angle(ai_left_angle[0]),
        .ai_right_angle(ai_right_angle[0]),
        .ai_action_cmd(ai_action_cmd[0])
    );

    simulator #(.TEAM(0), .SELF_INDEX(1)) u_simulator1(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle1_1),
        .area_angle2(area_angle1_2),
        .forward_mode(forward_mode1[1]),
        .Decision(decision_grp1[1]),
        .ai_left_angle(ai_left_angle[1]),
        .ai_right_angle(ai_right_angle[1]),
        .ai_action_cmd(ai_action_cmd[1])
    );
    simulator #(.TEAM(0), .SELF_INDEX(2)) u_simulator2(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle1_1),
        .area_angle2(area_angle1_2),
        .forward_mode(forward_mode1[2]),
        .Decision(decision_grp1[2]),
        .ai_left_angle(ai_left_angle[2]),
        .ai_right_angle(ai_right_angle[2]),
        .ai_action_cmd(ai_action_cmd[2])
    );
    simulator #(.TEAM(0), .SELF_INDEX(3)) u_simulator3(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle1_1),
        .area_angle2(area_angle1_2),
        .forward_mode(forward_mode1[3]),
        .Decision(decision_grp1[3]),
        .ai_left_angle(ai_left_angle[3]),
        .ai_right_angle(ai_right_angle[3]),
        .ai_action_cmd(ai_action_cmd[3])
    );
    keeper #(.TEAM(0)) u_keeper4(
        .self_info(player_info[4]),
        .ball_info(ball_info),
        .ai_left_angle(ai_left_angle[4]),
        .ai_right_angle(ai_right_angle[4]),
        .ai_action_cmd(ai_action_cmd[4])
    );
    simulator #(.TEAM(1), .SELF_INDEX(5)) u_simulator5(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle2_1),
        .area_angle2(area_angle2_2),
        .forward_mode(forward_mode2[0]),
        .Decision(decision_grp2[0]),
        .ai_left_angle(ai_left_angle[5]),
        .ai_right_angle(ai_right_angle[5]),
        .ai_action_cmd(ai_action_cmd[5])
    );
    simulator #(.TEAM(1), .SELF_INDEX(6)) u_simulator6(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle2_1),
        .area_angle2(area_angle2_2),
        .forward_mode(forward_mode2[1]),
        .Decision(decision_grp2[1]),
        .ai_left_angle(ai_left_angle[6]),
        .ai_right_angle(ai_right_angle[6]),
        .ai_action_cmd(ai_action_cmd[6])
    );
    simulator #(.TEAM(1), .SELF_INDEX(7)) u_simulator7(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle2_1),
        .area_angle2(area_angle2_2),
        .forward_mode(forward_mode2[2]),
        .Decision(decision_grp2[2]),
        .ai_left_angle(ai_left_angle[7]),
        .ai_right_angle(ai_right_angle[7]),
        .ai_action_cmd(ai_action_cmd[7])
    );
    simulator #(.TEAM(1), .SELF_INDEX(8)) u_simulator8(
        .simulator_game_clk(ai_game_clk),
        .rst(rst),
        .hold_index(hold_index),
        .player_info(player_info),
        .ball_info(ball_info),
        .area_angle1(area_angle2_1),
        .area_angle2(area_angle2_2),
        .forward_mode(forward_mode2[3]),
        .Decision(decision_grp2[3]),
        .ai_left_angle(ai_left_angle[8]),
        .ai_right_angle(ai_right_angle[8]),
        .ai_action_cmd(ai_action_cmd[8])
    );
    keeper #(.TEAM(1)) u_keeper9(
        .self_info(player_info[9]),
        .ball_info(ball_info),
        .ai_left_angle(ai_left_angle[9]),
        .ai_right_angle(ai_right_angle[9]),
        .ai_action_cmd(ai_action_cmd[9])
    );

endmodule