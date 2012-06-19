function processAllPrfns
%
% Script that processes all Prfns for the example data
format compact;

% add programs used to your path
addpath ../signalprocessing/
addpath ../inout/
addpath ../getinfo/
addpath ../plotting/
addpath ../deconvolution/

% parameters for processing.
opt.MINZ = 1; % min eqk depth
opt.MAXZ = 600; % max eqk depth
opt.DELMIN = 30; % min eqk distance
opt.DELMAX = 95; % max eqk distance
opt.PHASENM = 'P'; % phase to aim for
opt.TBEFORE = 30.0; % time before to cut
opt.TAFTER = 180.0; % time after p to cut
opt.TAPERW = 0.05; % proportion of seis to taper
opt.FLP = 2.0; % low pass
opt.FHP = 0.02; % high pass
opt.FORDER = 3; % order of filter
opt.DTOUT = 0.1; % desired sample interval
opt.MAGMIN = 5.5 % minimum magnitude to include
opt.MAGMAX = 8.0 % minimum magnitude to include

rfOpt.T0 = -10; % time limits for receiver function
rfOpt.T1 = 90;
rfOpt.F0 = 2.5; % gaussian width for filtering rfns
%rfOpt.F0 = 1.0; % gaussian width for filtering rfns
rfOpt.WLEVEL = 1e-2; % water level for rfn processing
rfOpt.ITERMAX = 200; %  max number of iterations in deconvolution
rfOpt.MINDERR = 1e-5; % min allowed change in RF fit for deconvolution

isCheck = false; % do everything auto
isPlot = false; % plot during rfn computing
isTRF = true; % also compute Transverse Rfs
isVb = true; % verbose output

% set the directory containing all event data in sub directories
basedir='./test_data/seismograms/'

% base directory for output
odir = './prfns/';
if( exist( odir , 'dir') ~= 7 ) unix( ['mkdir ', odir] ); end

% get the filenames for each event station pair three component files
enzfiles = getEvStaFilenames( basedir , 'BHE', 'BHN', 'BHZ');

% number of files
nf = length(enzfiles);
fprintf('Number of station-receiver pairs: %i\n', nf );

% go through each file
for i =1:nf,
%for i =1:1,

  % get the prefix of the file name
  fprintf('\n%s\n',enzfiles(i).name3)

  % Read the data
  try
    [eseis, nseis, zseis, hdr] = read3seis(enzfiles(i).name1, ...
					   enzfiles(i).name2, ...
					   enzfiles(i).name3 );
  catch ME
    disp(ME.message);
    continue;
  end

  % check depth units
  hdr.event.evdp = checkDepthUnits( hdr.event.evdp, 'km');

  % check conditions
  if( checkConditions(hdr, opt) ),
    % process and rotate
    [zseis, rseis, tseis, hdr] = processENZseis( eseis, nseis, zseis, ...
						 hdr, opt, isVb, isPlot );
  else
    fprintf('Didnt pass tests\n');
    continue;
  end


  % make the water level rfn, r over z
  if( isVb ), fprintf('Making Rfn water level...\n'); end
  [rftime, rfseis, rfhdr] = processRFwater(rseis, zseis, hdr, ...
					 rfOpt , false);

  % plot receiver functions
  if( isPlot ),
    clf;
    p1 = plot( rftime, rfseis, '-b', 'linewidth', 2 ); hold on;
  end

  % make the output file
  rfodir=[odir,sprintf('prfns_water_%0.2f/',rfOpt.F0)];
  ofname = getOfname( rfodir, rfhdr )

  % write
  writeSAC( ofname, rfhdr, rfseis );
  fprintf('Written to %s\n',ofname)

  % make the iterative rfn
  if( isVb ), fprintf('Making Rfn iterative...\n'); end
  [rftime, rfseis, rfhdr] = processRFiter(rseis, zseis, hdr, rfOpt , false);

  rfodir=[odir,sprintf('prfns_iter_%0.2f/',rfOpt.F0)];
  ofname = getOfname( rfodir, rfhdr );

  % write
  writeSAC( ofname, rfhdr, rfseis );
  fprintf('Written to %s\n',ofname)

  % plot
  if( isPlot ),
    p2 = plot( rftime, rfseis, '-r', 'linewidth', 2 );
    axis tight; xlabel('Time (s)'); ylabel('Amplitude (/s)');
    legend([p1,p2], 'water level', 'iterative')

    tmp = input('prompt');
  end
end

%--------------------------------------------------
function ofname = getOfname( rfodir, rfhdr )
% make the output directories and get the output file name
%

% check the output directory exists
if( exist( rfodir , 'dir') ~= 7 ) unix( ['mkdir ', rfodir] ); end

% make the station specific directory
staDIR = sprintf('%s_%s/',strtrim(rfhdr.station.knetwk),strtrim(rfhdr.station.kstnm) );
staDIR = [rfodir,staDIR];
if( exist( staDIR , 'dir') ~= 7 ) unix( ['mkdir ',staDIR] ); end

% make the station/event specific rfn
filename = sprintf('%04i_%03i_%02i%02i_%s_%s.PRF.sac', rfhdr.event.nzyear, ...
		   rfhdr.event.nzjday, rfhdr.event.nzhour, rfhdr.event.nzmin, ...
		   strtrim(rfhdr.station.knetwk), ...
		   strtrim(rfhdr.station.kstnm) );

ofname = [ staDIR, filename ];

% combine
return

% ----------------------------------------------------------------------