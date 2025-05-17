/***********  显存交换器  *************/
// 负责向video RAM发送batch;
// 每处理完一次发送，向外界发送一个信号，将控制权转交给render
// 累计一定次数后会耗尽，然后上层的vm_manager会交换这两块显存

module vm_switch
// 这里的BATCHSIZE表示：每次交换8字节，需要5120轮，也就是8*5120B = 40KB
#(parameter BATCHSIZE=5120)
(
    input ui_clk,
    input ui_rst,
    //和上层的接口
    input [5:0] frame_counter,  
    input vm_flag,           //负责交换分区; 0代表用BUF2，1代表用BUF1
    input switch_begin,             // 开始新一轮的交换（上层的vm_manager.sv需要严格控制交换次数）
    output reg switch_end,         //本轮的batch交换完成
    //与SDRAM的接口
    output [1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    output [29:0] operate_addr,      //地址
    input reg [63:0] read_data,
    input reg cmd_done             //这一轮命令结束
    //与video的接口
    output reg [63:0] write_data,   //[TODO]研究SRAM的字节序，注意进行顺序变换
    output reg [13:0] write_addr,   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
    output reg write_enable
);
    reg last_cmd_done;      //捕捉上升沿
    reg [13:0] switch_counter;      //负责BATCHSIZE的计数
    reg [2:0] switch_stat;
    reg switch_end_delay_counter;
    localparam [2:0] IDLE=0,REQ=1 ,SWAP=2, DONE=3;
    always@(posedge ui_clk)begin
        if(ui_rst)begin
            switch_stat <= IDLE;
            switch_counter <= 14'd0;
            switch_end_delay_counter <= 1'b0;
            //输出到video的信号初始化
            write_data <= 64'd0;
            write_addr <= 14'd0;
            write_enable <= 1'b0;
        end else begin
            if(switch_stat == IDLE)begin
                if(switch_begin)begin
                    //计算地址变化
                    switch_stat <= REQ;
                end
            end else if(switch_stat == REQ)begin    //请求数据
                sdram_cmd <= 2'd1;
                operate_addr <= (vm_flag ? BUF1_START : BUF2_START) + frame_counter * 40*KB + switch_counter * 8;    //每次读取8个字节，在switch_counter增加的过程中，会自动进行地址偏移
                if(~last_cmd_done & cmd_done)begin
                    sdram_cmd <= 2'd0;
                    //将设置write_addr和write_data提前，保证稳定
                    write_addr <= switch_counter;
                    //这里进行字节顺序的变换，使得RAM中读取到的像素数据顺序正确
                    write_data <= {read_data[15:0], read_data[31:16], read_data[47:32], read_data[63:48]};
                    switch_stat <= SWAP;
                end
            end else if(switch_stat == SWAP)begin   //交换
                write_enable <= 1'b1;
                if(switch_counter == BATCHSIZE - 1)begin
                    switch_counter <= 0;
                    switch_end <= 1'b1;     //拉高交换完成的信号
                    switch_stat <= DONE;
                end else begin
                    switch_counter <= switch_counter + 1;
                    switch_stat <= REQ;       // 下一个请求
                end
            end else begin                          //DONE
                if(delay_show_counter == 1'b0)begin
                    delay_show_counter <= 1'b1;
                end else begin
                    delay_show_counter <= 1'b0;
                    switch_end <= 1'b0;     // 恢复信号
                    switch_stat <= IDLE;    // 等待下一次batch fill的请求
                end
            end
            last_cmd_done <= cmd_done;
        
        end
    end


endmodule