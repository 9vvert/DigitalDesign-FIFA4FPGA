module ai_controller(
    input ai_game_clk,
    input rst,
    // //同队信息
    // input PlayerInfo self_info,
    // input PlayerInfo teammate_info[4],
    // //对手信息
    // input PlayerInfo arival_info[5],    
    // //辅助信息
    // input BallInfo ball_info,
    


    output reg [7:0] ai_left_angle,
    output reg [7:0] ai_right_angle,
    output reg [7:0] ai_action_cmd
);
    always@(posedge ai_game_clk) begin
        if(rst)begin
            ai_left_angle <= 'hFF;
            ai_right_angle <= 'hFF;
            ai_action_cmd <= 'h00;
        end else begin
            ;
        end 
    end


endmodule