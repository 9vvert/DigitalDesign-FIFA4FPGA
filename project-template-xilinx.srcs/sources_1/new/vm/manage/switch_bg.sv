// 进行背景的切换
// 目前的小图片管理机制是： 每一个type有1000个扇区
// 支持10个类，从第10000个扇区开始作为background的存储地址，每个2MB = 4096个扇区，预留5000个扇区的位置
// 因此映射关系为： start_sector = 10000 + 5000*bg_index，换算成地址还要乘以512
// 初步估计拷贝时间：60ms
module switch_bg
#(parameter BG_WIDTH=1280, BG_HEIGHT=720)
(
    input switch_bg_ui_clk,
    input ui_rst,
    // 与game controller交互
    input switch_begin,
    input [5:0] bg_index,       // 使用的场景编号，应该也有一个映射
    output reg switch_end,
    // 与SDRAM交互的信号
    output reg[1:0] sdram_cmd,          //命令，  0无效，1读取，2写入
    output reg[29:0] operate_addr,      //地址
    input [63:0] read_data,
    input cmd_done,
    //与SRAM的接口
    output reg sram_io_req,        //读写请求
    output reg [19:0] times,       //读写次数
    output reg wr,                 //是否选择“写”
    output [19:0] addr,
    output reg [31:0] din          // 渲染信息
);
    localparam [3:0] IDLE=0, READ1=1, READ2=2, WRITE1=3, WRITE2=4, WRITE3=5, PRE_READ=6, PRE_WRITE=7,DONE=8,REQ=11, COPY=12;
    reg [3:0] bg_stat;
    reg last_cmd_done;          // 捕捉上升沿
    reg [19:0] block_counter;   // 256B为一个块，一共需要拷贝7200个Block （而且要向两份显存都拷贝）
    reg [7:0] req_counter;  //请求32次
    reg [7:0] copy_counter; //拷贝64*2 = 128次
    reg [31:0] buffer[63:0];
    reg done_delay_counter;

    assign addr = (copy_counter[0] ? 0 : 524288) + (copy_counter>>1) + 64*block_counter;

    always@(posedge switch_bg_ui_clk)begin
        if(ui_rst)begin
            block_counter <= 0;
            req_counter <= 0;
            copy_counter <= 0;
            done_delay_counter <= 0;
            switch_end <= 0;
            bg_stat <= IDLE;
        end else begin
            if(bg_stat == IDLE)begin
                if(switch_begin)begin
                    //先计算出 operate_addr
                    //[ TODO ]自己在计算地址的时候，是否忽略了位宽没有自动扩展的情况？
                    operate_addr <= (10000 + 5000*bg_index)*512;
                    block_counter <= 0;
                    req_counter <= 0;
                    copy_counter <= 0;
                    bg_stat <= REQ;
                end
            end else if(bg_stat == REQ)begin
                //向SDRAM请求数据，每次8字节，一共32次
                sdram_cmd <= 2'd1;
                if(~last_cmd_done & cmd_done)begin
                    sdram_cmd <= 2'd0;
                    buffer[2*req_counter] <= {read_data[15:0], read_data[31:16]};
                    buffer[2*req_counter+1] <= {read_data[47:32], read_data[63:48]};
                    // 下一次req
                    if(req_counter == 31)begin
                        //请求完256Bytes，开始进行一轮写入
                        req_counter <= 0;
                        bg_stat <= COPY;
                    end else begin
                        req_counter <= req_counter + 1;
                        operate_addr <= operate_addr + 8;   //地址变化
                    end
                end
                
            end else if(bg_stat == COPY)begin
                sram_io_req <= 1;
                wr <= 1;            // 写的请求
                bg_stat <= PRE_WRITE;
            end else if(bg_stat == PRE_WRITE)begin
                times <= 128;           // 每个显存块都需要64次
                din <= buffer[(copy_counter>>1)];
                bg_stat <= WRITE1;
            end else if(bg_stat == WRITE1)begin
                sram_io_req <= 0;
                bg_stat <= WRITE2;
            end else if(bg_stat == WRITE2)begin
                bg_stat <= WRITE3;
            end else if(bg_stat == WRITE3)begin
                if(copy_counter == 127)begin
                    copy_counter <= 0;
                    // 完成一个block，开启下一个
                    if(block_counter == (TEST_DEBUG ? 255 : 7199))begin
                        // 彻底结束
                        switch_end <= 1;
                        bg_stat <= DONE;
                    end else begin
                        block_counter <= block_counter + 1;
                        operate_addr <= operate_addr + 8;
                        req_counter <= 0;
                        bg_stat <= REQ;
                    end
                end else begin
                    copy_counter <= copy_counter + 1;
                    din <= buffer[(copy_counter>>1)];
                    bg_stat <= WRITE1;
                end
            end else begin      // DONE
                if(done_delay_counter == 0)begin
                    done_delay_counter <= 1;
                end else begin
                    done_delay_counter <= 0;
                    switch_end <= 0;
                end
            end
            last_cmd_done <= cmd_done;
        end
    end

endmodule