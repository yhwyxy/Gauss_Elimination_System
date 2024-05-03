`timescale 1ns / 1ps

module tb_Gauss_Elimination_System;

    // 鍙傛暟瀹氫箟
    localparam Width = 32;
    localparam N = 9;
    localparam Integer_Depth = N * N;

    // 杈撳叆杈撳嚭淇″彿瀹氫箟
    reg clk, rst_n, start;
    wire done, error_flag;

    // 鐭╅樀鍜岃В鐨勫瓨鍌ㄦ暟缁�
    reg [Width-1:0] matrix[N*N-1:0];
    reg [Width-1:0] solution[N-1:0];

    // 瀹炰緥鍖栬娴嬭瘯妯″潡
    Gauss_Elimination_System uut(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .error_flag(error_flag)
    );

    // 鏃堕挓鐢熸垚
    initial begin
        clk = 0;
        forever #5 clk = !clk;  // 浜х敓涓�涓懆鏈熶负10ns鐨勬椂閽熶俊鍙�
    end

    initial begin
        $readmemh("W:/Vivado/projects/Gauss_Elimination/Gauss_Elimination.srcs/sources_1/matrix_data.mem", matrix);

        #10; // 延迟一段时间确保数据加载完成
        for (int i = 0; i < 81; i++) begin
            $display("matrix[%0d] = %h", i, matrix[i]);
        end
    end

    // 娴嬭瘯婵�鍔�
    initial begin
        // 鍒濆鍖�
        rst_n = 0; start = 0;
        #10;
        rst_n = 1;

        // 鍔犺浇鐭╅樀鏁版嵁
        $readmemh("W:/Vivado/projects/Gauss_Elimination/Gauss_Elimination.srcs/sources_1/matrix_data.mem", matrix);

//        $readmemh("./srcs/sources_1/matrix_data.mem", matrix);
         // 鍋囪鏈変竴涓悕涓簃atrix_data.mem鐨勬枃浠跺寘鍚簡鐭╅樀鏁版嵁

        // 鍚姩璁＄畻
        #10;
        start = 1;
        #10;
        start = 0;

        // 绛夊緟瀹屾垚
        wait (done == 1);
        #10;

        // 妫�鏌ラ敊璇爣蹇�
        if (error_flag) begin
            $display("Error: Solution verification failed.");
        end else begin
            $display("Test passed: Solution verified successfully.");
        end

        // 璇诲彇瑙ｅ悜閲忓苟鎵撳嵃缁撴灉
        $readmemh("solution.mem", solution); // 鍋囪solution.mem鍖呭惈浜嗘湡鏈涚殑瑙ｅ悜閲�
        for (int i = 0; i < N; i++) begin
            $display("x[%0d] = %h", i, solution[i]);
        end

        // 娴嬭瘯缁撴潫
        $finish;
    end

endmodule
