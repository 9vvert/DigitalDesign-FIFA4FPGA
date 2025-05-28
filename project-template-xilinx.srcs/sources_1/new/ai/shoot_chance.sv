// 评估射门的几率
module shoot_chance
#(parameter TOP_X=600, TOP_Y=400, BOT_X=600,BOT_Y=200)      //球网的两个点  // 后续交换一组
(
    input ai_clk,                       // 100MHz
    input ai_rst,
    input game_clk,                     // 1KHz
    input PlayerInfo self_info,
    input PlayerInfo [4:0] rival_info, 

    output [9:0] points         // 估计决策分数
);
    import TrianglevalLib::*;

    
    // 自己距离球门过远会减分；按照路径上最近的敌人扣分
    always@(posedge ai_clk)begin
        if(ai_rst)begin
            ;
        end begin
            
        end
    end
    


endmodule