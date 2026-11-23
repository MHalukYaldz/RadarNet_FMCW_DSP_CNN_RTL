----------------------------------------------------------------------------------
--Engineer: Mustafa Haluk Yaldız
--Module Name: range_fft
--Target Devices: Pnyq-Z2 
--Tool Versions: Vivado 2025.2
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity range_fft is
  Port (
    aclk                        : IN  STD_LOGIC;
    aresetn                     : IN  STD_LOGIC;

    -- Hann bloğundan gelen kompleks örnekler
    s_axis_tdata                : IN  STD_LOGIC_VECTOR(31 downto 0);
    s_axis_tvalid               : IN  STD_LOGIC;
    s_axis_tready               : OUT STD_LOGIC;
    s_axis_tlast                : IN  STD_LOGIC;

    -- FFT sonuçları ve frekans indeksi
    m_axis_tdata                : OUT STD_LOGIC_VECTOR(63 downto 0);
    m_axis_tuser                : OUT STD_LOGIC_VECTOR(7 downto 0);
    m_axis_tvalid               : OUT STD_LOGIC;
    m_axis_tready               : IN  STD_LOGIC;
    m_axis_tlast                : OUT STD_LOGIC;
    
    -- Yapılandırma ve kontrol sinyalleri
    configured                  : out STD_LOGIC;
    event_frame_started         : out STD_LOGIC;
    event_tlast_unexpected      : out STD_LOGIC;
    event_tlast_missing         : out STD_LOGIC;
    event_status_channel_halt   : out STD_LOGIC;
    event_data_in_channel_halt  : out STD_LOGIC;
    event_data_out_channel_halt : out STD_LOGIC
  );
end range_fft;

architecture RTL of range_fft is

    component range_fft_ip
        port(
            aclk                        : IN  STD_LOGIC;       
            aresetn                     : IN  STD_LOGIC;    
            
            s_axis_config_tdata         : IN  STD_LOGIC_VECTOR(7 downto 0);
            s_axis_config_tvalid        : IN  STD_LOGIC;
            s_axis_config_tready        : OUT STD_LOGIC;
            
            s_axis_data_tdata           : IN  STD_LOGIC_VECTOR(31 downto 0);
            s_axis_data_tvalid          : IN  STD_LOGIC;
            s_axis_data_tready          : OUT STD_LOGIC;
            s_axis_data_tlast           : IN  STD_LOGIC;
            
            m_axis_data_tdata           : OUT STD_LOGIC_VECTOR(63 downto 0);
            m_axis_data_tuser           : OUT STD_LOGIC_VECTOR(7 downto 0);
            m_axis_data_tvalid          : OUT STD_LOGIC;
            m_axis_data_tready          : IN  STD_LOGIC;
            m_axis_data_tlast           : OUT STD_LOGIC;
            
            event_frame_started         : OUT STD_LOGIC;
            event_tlast_unexpected      : OUT STD_LOGIC;
            event_tlast_missing         : OUT STD_LOGIC;
            event_status_channel_halt   : OUT STD_LOGIC;
            event_data_in_channel_halt  : OUT STD_LOGIC;
            event_data_out_channel_halt : OUT STD_LOGIC
        );
    end component;
    
    -- Bit 0 = 1: İleri FFT
    constant FFT_CONFIG : STD_LOGIC_VECTOR(7 downto 0):= x"01";
    
    signal config_done      : STD_LOGIC;
    signal config_valid     : STD_LOGIC;
    signal config_ready     : STD_LOGIC;
    
    signal data_enable      : STD_LOGIC;
    signal fft_data_valid   : STD_LOGIC;
    signal fft_data_ready   : STD_LOGIC;

begin
    
    -- Ayar kabul edilene kadar valid high kalır
    config_valid <= aresetn AND NOT config_done;
    
    -- Veri akışını sadece yapılandırma tamamlanınca aç
    data_enable <= aresetn AND config_done;
    
    fft_data_valid <= s_axis_tvalid AND data_enable;
    s_axis_tready  <= fft_data_ready AND data_enable;
    
    configured <= data_enable;
    
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                config_done <= '0';
            elsif config_valid = '1' AND config_ready = '1' then
                config_done <= '1';
            end if;
        end if;
    end process;
    
    u_fft : range_fft_ip
        port map(
            aclk                 => aclk                ,
            aresetn              => aresetn             ,
            
            s_axis_config_tdata  => FFT_CONFIG          ,
            s_axis_config_tvalid => config_valid        ,
            s_axis_config_tready => config_ready        ,

            s_axis_data_tdata    => s_axis_tdata        ,
            s_axis_data_tvalid   => fft_data_valid      ,
            s_axis_data_tready   => fft_data_ready      ,
            s_axis_data_tlast    => s_axis_tlast        ,

            m_axis_data_tdata    => m_axis_tdata        ,
            m_axis_data_tuser    => m_axis_tuser        ,
            m_axis_data_tvalid   => m_axis_tvalid       ,
            m_axis_data_tready   => m_axis_tready       ,
            m_axis_data_tlast    => m_axis_tlast        ,
            
            event_frame_started         => event_frame_started,               
            event_tlast_unexpected      => event_tlast_unexpected,         
            event_tlast_missing         => event_tlast_missing,               
            event_status_channel_halt   => event_status_channel_halt,   
            event_data_in_channel_halt  => event_data_in_channel_halt, 
            event_data_out_channel_halt => event_data_out_channel_halt
        );
end RTL;
