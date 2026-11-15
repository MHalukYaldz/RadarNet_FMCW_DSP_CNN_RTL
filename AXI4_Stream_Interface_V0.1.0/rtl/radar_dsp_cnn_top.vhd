----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: axis_transaction
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------
     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity radar_dsp_cnn_top is
  Port (aclk            : IN  STD_LOGIC;
        aresetn         : IN  STD_LOGIC;
     
        s_axis_tdata    : IN  STD_LOGIC_VECTOR(31 downto 0);
        s_axis_tvalid   : IN  STD_LOGIC;
        s_axis_tready   : OUT STD_LOGIC;
        s_axis_tlast    : IN  STD_LOGIC;
     
        m_axis_tdata    : OUT STD_LOGIC_VECTOR(31 downto 0);
        m_axis_tvalid   : OUT STD_LOGIC;
        m_axis_tready   : IN  STD_LOGIC;
        m_axis_tlast    : OUT STD_LOGIC
        );
end radar_dsp_cnn_top;

architecture Structural of radar_dsp_cnn_top is
begin
    
    u_input_buffer : entity work.axis_register_slice
        port map(
            aclk            => aclk,            
            aresetn         => aresetn,         
                                            
            s_axis_tdata    => s_axis_tdata,    
            s_axis_tvalid   => s_axis_tvalid,   
            s_axis_tready   => s_axis_tready,   
            s_axis_tlast    => s_axis_tlast,    
                                           
            m_axis_tdata    => m_axis_tdata,    
            m_axis_tvalid   => m_axis_tvalid,   
            m_axis_tready   => m_axis_tready,   
            m_axis_tlast    => m_axis_tlast    
        );

end Structural;
