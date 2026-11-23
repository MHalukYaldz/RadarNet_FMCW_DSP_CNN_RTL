----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: radar_dsp_cnn_top
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------
     
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity radar_dsp_cnn_top is
  Port (aclk                        : IN  STD_LOGIC;
        aresetn                     : IN  STD_LOGIC;
     
        s_axis_tdata                : IN  STD_LOGIC_VECTOR(31 downto 0);
        s_axis_tvalid               : IN  STD_LOGIC;
        s_axis_tready               : OUT STD_LOGIC;
        s_axis_tlast                : IN  STD_LOGIC;
     
        m_axis_tdata                : OUT STD_LOGIC_VECTOR(63 downto 0);
        m_axis_tuser                : OUT STD_LOGIC_VECTOR(7 downto 0);
        m_axis_tvalid               : OUT STD_LOGIC;
        m_axis_tready               : IN  STD_LOGIC;
        m_axis_tlast                : OUT STD_LOGIC;
        
        fft_configured              : out STD_LOGIC;
        event_frame_started         : out STD_LOGIC;
        event_tlast_unexpected      : out STD_LOGIC;
        event_tlast_missing         : out STD_LOGIC;
        event_status_channel_halt   : out STD_LOGIC;
        event_data_in_channel_halt  : out STD_LOGIC;
        event_data_out_channel_halt : out STD_LOGIC
        );
end radar_dsp_cnn_top;

architecture Structural of radar_dsp_cnn_top is
-----------------------------------------------------------------------------------
--  Register Slice ile HANN bloğu arasındaki bağlantılar
    signal slice_data   : STD_LOGIC_VECTOR(31 downto 0);
    signal slice_valid  : STD_LOGIC;
    signal slice_ready  : STD_LOGIC;
    signal slice_last   : STD_LOGIC;
    
    -- Hann ile FFT arasındaki bağlantı
    signal window_data  : STD_LOGIC_VECTOR(31 downto 0);
    signal window_valid : STD_LOGIC;
    signal window_ready : STD_LOGIC;
    signal window_last  : STD_LOGIC;
-----------------------------------------------------------------------------------
begin
    
    u_register_slice : entity work.axis_register_slice
        port map(
            aclk                        => aclk,            
            aresetn                     => aresetn,         
                                                        
            s_axis_tdata                => s_axis_tdata,    
            s_axis_tvalid               => s_axis_tvalid,   
            s_axis_tready               => s_axis_tready,   
            s_axis_tlast                => s_axis_tlast,    
                                                       
            m_axis_tdata                => slice_data,
            m_axis_tvalid               => slice_valid,
            m_axis_tready               => slice_ready,
            m_axis_tlast                => slice_last
        );
    u_range_window : entity work.range_window
        port map(
            aclk                        => aclk,
            aresetn                     => aresetn,
            
            s_axis_tdata                => slice_data,
            s_axis_tvalid               => slice_valid,
            s_axis_tready               => slice_ready,
            s_axis_tlast                => slice_last,
            
            m_axis_tdata                => window_data,
            m_axis_tvalid               => window_valid,
            m_axis_tready               => window_ready,
            m_axis_tlast                => window_last 
        );
        
    u_range_range : entity work.range_fft
        port map(
            aclk                        => aclk                       ,
            aresetn                     => aresetn                    ,

            s_axis_tdata                => window_data                ,
            s_axis_tvalid               => window_valid               ,
            s_axis_tready               => window_ready               ,
            s_axis_tlast                => window_last                ,

            m_axis_tdata                => m_axis_tdata               ,
            m_axis_tuser                => m_axis_tuser               ,
            m_axis_tvalid               => m_axis_tvalid              ,
            m_axis_tready               => m_axis_tready              ,
            m_axis_tlast                => m_axis_tlast               ,

            configured                  => fft_configured             ,
            event_frame_started         => event_frame_started        ,
            event_tlast_unexpected      => event_tlast_unexpected     ,
            event_tlast_missing         => event_tlast_missing        ,
            event_status_channel_halt   => event_status_channel_halt  ,
            event_data_in_channel_halt  => event_data_in_channel_halt ,
            event_data_out_channel_halt => event_data_out_channel_halt
        );

end Structural;
