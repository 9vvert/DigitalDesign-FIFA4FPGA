// 可以完成很多模块，然后用仲裁器进行选择

// action_chooser的作用是集成并选择不同的动作状态机
// 这里的action是除了跑步之外的、同一时间内互斥的动作，而且还有可能会改变上层的动作(angle等)
module action_HFSM(
    input game_clk,
    input rst,
    input ready,    //进入动作
    output reg done,    //完成动作，用于释放action_mutex
    //是否持球
    

    input holding,
    input action,       // 外部决定用什么动作
    


    //
    
    
    output reg action_message;        // 比如进行抢断时，是否判定成功
    

);

    localparam IDLE = 8'd0;
    always @(posedge game_clk) begin
        if(rst) begin
            //
        end else begin
            //
        end
    end

endmodule