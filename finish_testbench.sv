`timescale 1ns / 1ps

module tb_Gauss_Elimination_System;
    localparam int N = 9;
    reg clk, rst_n, start;
    wire done, error_flag;
    wire [8:0][31:0] solution;
    
    // Unpacked memory for $readmemh, then copy to packed port signals
    reg [31:0] matrix_mem [0:80];
    reg [31:0] b_mem [0:8];
    reg [80:0][31:0] matrix_A;
    reg [8:0][31:0]  vector_b;
    integer i, cycle_count;

    Gauss_Elimination_System uut(
        .clk(clk), .rst_n(rst_n), .start(start),
        .matrix_external(matrix_A), .b_external(vector_b),
        .done(done), .error_flag(error_flag), .solution(solution)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        $readmemh("matrix_data.mem", matrix_mem);
        $readmemh("b_data.mem", b_mem);
        for (i = 0; i < 81; i = i + 1) matrix_A[i] = matrix_mem[i];
        for (i = 0; i < 9; i = i + 1)  vector_b[i] = b_mem[i];
    end

    initial begin
        $display("Test started.");
        rst_n = 0; start = 0;
        cycle_count = 0;
        #20 rst_n = 1;
        #10;

        $display("Loaded matrix_A[0]=%h matrix_A[9]=%h b[0]=%h",
            matrix_A[0], matrix_A[9], vector_b[0]);

        start = 1;
        #10 start = 0;

        while (!done && cycle_count < 20000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        #20;
        $display("Done after %0d cycles. error_flag=%b", cycle_count, error_flag);

        if (!error_flag) begin
            $display("Test PASSED. Solution vector:");
            for (i = 0; i < N; i = i + 1)
                $display("  x[%0d] = %h", i, solution[i]);
        end else begin
            $display("Test FAILED.");
            $display("Master state=%0d", uut.master_inst.state);
            $display("Slave1: state=%0d done=%b error=%b",
                uut.slave1_inst.fe_state, uut.slave1_inst.done_out, uut.slave1_inst.error_out);
            $display("Slave2: state=%0d done=%b error=%b",
                uut.slave2_inst.bs_state, uut.slave2_inst.done_out, uut.slave2_inst.error_out);
        end

        $finish;
    end
endmodule
