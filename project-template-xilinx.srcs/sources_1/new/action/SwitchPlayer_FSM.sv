module SwichPlayer_FSM
#(parameter TOL_ANG = 9)
(
    input SwichPlayer_FSM_game_clk,
    input rst,

    input switch_start;
    input [7:0] switch_angle,       //右侧摇杆的角度

    input [15:0] player_x,
    input [15:0] player_y,
    input [15:0] football_x,
    input [15:0] football_y,   //这里不用考虑football_z
    //其它球员的信息
    player_info.output_modport teammate_1,      //第一个队友

    output SwichPlayer_FSM_done,
    output [3:0] SwichPlayer_FSM_message    //0无效，1/2/3/4/...分别表示切换到相应的球员；  15表示失败
);

    reg last_switch_start;
    reg ready;
    reg [5:0] SwichPlayer_FSM_stat;
    // 后续逐渐增加
    wire [31:0] dis_1;
    //
    wire [7:0] delta_ang1;  //个人和球员的夹角

    //人和球的距离
    assign dis_0 = distance(player_x,player_y ,football_x, football_y); // 自己的距离
    assign dis_1 = distance(teammate_1.sx,teammate_1.sy ,football_x, football_y);
    // assign dis_0 = distance(player_x,player_y ,football_x, football_y);
    // assign dis_0 = distance(player_x,player_y ,football_x, football_y);
    // assign dis_0 = distance(player_x,player_y ,football_x, football_y);

    //人和人的角度
    assign delta_ang1 = rel_angle_val(switch_angle, vec2angle(player_x,player_y,teammate_1.sx,teammate_1.sy));
    
    /************    ***********/

    localparam [5:0] IDLE = 6'd0, SWITCH = 6'd1, DONE = 6'd2;

    always@(posedge SwichPlayer_FSM_game_clk)begin
        if(rst)begin
            SwichPlayer_FSM_done <= 1'b0;
            SwichPlayer_FSM_message <= 2'd0;
            last_switch_start <= 1'b0;
            ready <= 1'b0;
        end else begin
            ready = (last_switch_start == 1'b0) && (switch_start == 1'b1);
            last_switch_start = switch_start;
            if(SwichPlayer_FSM_stat == IDLE)begin
                if(ready)begin
                    SwichPlayer_FSM_stat <= SWITCH;
                end else begin
                    SwichPlayer_FSM_stat <= IDLE;
                end
            end else if(SwichPlayer_FSM_stat == SWITCH)begin
                if(switch_angle < 8'd72)begin   //按照角度切换，但还是有一定的范围
                    if(delta_ang1 < TOL_ANG)begin
                        SwichPlayer_FSM_message <= 4'd1;
                    end else begin
                        SwichPlayer_FSM_message <=  4'd15;
                    end
                    SwichPlayer_FSM_stat <= DONE;
                end else begin      //这种情况下视为没有按下摇杆，切换到除了自己外距离最近的单位
                    //现在只有一个球员，直接切换
                    SwichPlayer_FSM_message <= 4'd1;
                    SwichPlayer_FSM_stat <= DONE;
                end
                SwichPlayer_FSM_done <= 1'b1;
            end else if(SwichPlayer_FSM_stat == DONE)begin
                SwichPlayer_FSM_done <= 1'b0;
                SwichPlayer_FSM_stat <= IDLE;
            end 
        end
    end


endmodule