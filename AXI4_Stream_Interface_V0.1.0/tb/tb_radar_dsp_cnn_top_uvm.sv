`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mustafa Haluk Yaldız
// Module Name: axis_transaction
// Target Devices: Pnyq-Z2 
// Tool Versions: Vivado 2025.2
//////////////////////////////////////////////////////////////////////////////////


module tb_radar_dsp_cnn_top_uvm;

    import uvm_pkg::*;
    import axis_uvm_pkg::*;
    
    // Gerçek interface örneği
    axis_uvm_if bus();
    
    // VHDL Tasarım
    radar_dsp_cnn_top dut(
        .aclk           (bus.aclk),
        .aresetn        (bus.aresetn),
        
        .s_axis_tdata   (bus.s_axis_tdata),
        .s_axis_tvalid  (bus.s_axis_tvalid),
        .s_axis_tready  (bus.s_axis_tready),
        .s_axis_tlast   (bus.s_axis_tlast),
        
        .m_axis_tdata   (bus.m_axis_tdata),
        .m_axis_tvalid  (bus.m_axis_tvalid),
        .m_axis_tready  (bus.m_axis_tready),
        .m_axis_tlast   (bus.m_axis_tlast)
    );
    
    // 50 MHz clock
    initial begin
        bus.aclk = 1'b0;
        
        forever #10 bus.aclk = ~bus.aclk;
    end
    
    // Başlangıç reseti
    initial begin
        bus.aresetn = 1'b0;
        
        repeat(2) @(negedge bus.aclk);
        
        // Reset çıkışı clock tan biraz ayrılsın
        #1;
        bus.aresetn = 1'b1;
    end
    
    // Interface i UVM bileşenleriyle paylaş ve test başlangıcı
    initial begin
        uvm_config_db#(virtual axis_uvm_if)::set(
            null,
            "uvm_test_top*",
            "vif",
            bus
        );
        
        run_test("axis_random_test");
    end
endmodule
