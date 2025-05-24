/***********  显存交换器  *************/
// 负责向video RAM发送batch;
// 每处理完一次发送，向外界发送一个信号，将控制权转交给render
// 累计一定次数后会耗尽，然后上层的vm_manager会交换这两块显存
module vm_switch
// SRAM每次可以读取4字节，因此发送20KB的数据需要5120轮
#(parameter SWAP_TIME = TEST_DEBUG ? 2048 : 7680, BATCH_SKIP = TEST_DEBUG ? 2048: 7680 )
(
    output reg[31:0] debug_number,
    input vm_switch_ui_clk,
    input ui_rst,
    //和上层的接口
    input [6:0] frame_counter,  
    input vm_flag,           //负责交换分区; 0代表用BUF2，1代表用BUF1
    input switch_begin,             // 开始新一轮的交换（上层的vm_manager.sv需要严格控制交换次数）
    output reg switch_end,         //本轮的batch交换完成
    //与SRAM的接口
    output reg sram_io_req,        //读写请求
    output reg [19:0] times,       //读写次数
    output reg wr,                 //是否选择“写”
    output reg [19:0] addr,        
    input wire [31:0] dout,     //[TODO] SRAM有无字节大小端的问题？
    //与video的接口
    output reg [31:0] write_data,   //[TODO]研究SRAM的字节序，注意进行顺序变换
    output reg [14:0] write_addr,   //每一个batch，write_addr都是从0开始逐渐增减，在video.sv中会再进行一轮变换
    output reg write_enable
);
    reg [19:0] switch_counter;      //负责BATCHSIZE的计数
    reg [3:0] switch_stat;
    reg switch_end_delay_counter;

    localparam [3:0] IDLE=0, READ1=1, READ2=2, WRITE1=3, WRITE2=4, WRITE3=5, PRE_READ=6, PRE_WRITE=7,DONE=8;
    always@(posedge vm_switch_ui_clk)begin
        if(ui_rst)begin
            switch_stat <= IDLE;
            switch_counter <= 20'd0;
            switch_end_delay_counter <= 1'b0;
            //输出到video的信号初始化
            write_data <= 32'd0;
            write_addr <= 14'd0;
            write_enable <= 1'b0;
        end else begin
            if(switch_stat == IDLE)begin
                write_enable <= 1'b0;
                if(switch_begin)begin               //相当于 test_sram中的IDLE
                    sram_io_req <= 1'b1;        //拉高请求
                    times <= SWAP_TIME;
                    wr <= 1'b0;                 //读数据
                    switch_stat <= PRE_READ;        //必须保证和sram_IO内部同步
                end
            end else if(switch_stat == PRE_READ)begin
                addr <= (vm_flag ? BUF1_START : BUF2_START) + frame_counter*BATCH_SKIP + switch_counter;
                switch_stat <= READ1;
            end else if(switch_stat == READ1)begin
                // 负责原来的SWAP部分，这会将上一轮的READ2中设置的write_data写入
                if(switch_counter > 0)begin
                    write_enable <= 1;           //第一个周期不需要发
                end
                //
                switch_stat <= READ2;
            end else if(switch_stat == READ2)begin
                sram_io_req <= 0;       // 这个时候拉低req是绝对安全的
                // 在READ2周期内，dout可以读取
                write_enable <= 0;      //[TODO]这样是否可行？
                write_addr <= switch_counter;
                write_data <= {dout[15:0], dout[31:16]};        //[TODO]验证字节序
                if(switch_counter == SWAP_TIME - 1)begin
                    //已经完成，退出
                    switch_counter <= 0;
                    switch_end <= 1;        // 这里不要忘记拉高end信号
                    switch_stat <= DONE;
                end else begin
                    //控制
                    wr <= 0;
                    addr <= addr + 1;   
                    switch_counter <= switch_counter + 1;
                    switch_stat <= READ1;       //新的一轮
                    
                end
            end else begin                          //DONE
                if(switch_end_delay_counter == 1'b0)begin
                    write_enable <= 1'b1;           // 充当READ1的作用，这里发送的是最后一轮的数据
                    switch_end_delay_counter <= 1'b1;
                end else begin
                    write_enable <= 1'b0; 
                    switch_end_delay_counter <= 1'b0;
                    switch_end <= 1'b0;     // 恢复信号
                    switch_stat <= IDLE;    // 等待下一次batch fill的请求
                end
            end
        end
    end
endmodule