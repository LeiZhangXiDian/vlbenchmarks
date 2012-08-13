function benchmarkDemo()
% BENCHMARKDEMO Script demonstrating how to run the benchmarks for
%   different algorithms.
%

%% Define Local features detectors

import localFeatures.*;

detectors{1} = vggMser('ms',30); % Custom options
detectors{2} = vlFeatMser(); % Default options
detectors{2}.detectorName = 'VLFeat MSER'; % used in the plot legend by modifying the above field
detectors{3} = cmpHessian();
detectors{4} = vlFeatCovdet('AffineAdaptation',true,'Orientation',false,'Method','hessian');
detectors{5} = vggAffine('Detector', 'hessian');

%% Define dataset

import datasets.*;

dataset = vggAffineDataset('category','graf');

%% Define benchmarks

import benchmarks.*;

repBenchmark = repeatabilityBenchmark();
kmBenchmark = kristianEvalBenchmark();

%% Run the benchmarks in parallel

numDetectors = numel(detectors);
numImages = dataset.numImages;

repeatability = zeros(numDetectors, numImages);
numCorresp = zeros(numDetectors, numImages);

matchScore = zeros(numDetectors, numImages);
numMatches = zeros(numDetectors, numImages);


% Test all detectors
for detectorIdx = 1:numDetectors
  detector = detectors{detectorIdx};
  imageAPath = dataset.getImagePath(1);
  
  parfor imageIdx = 2:numImages
    imageBPath = dataset.getImagePath(imageIdx);
    tf = dataset.getTransformation(imageIdx);
    [repeatability(detectorIdx,imageIdx) numCorresp(detectorIdx,imageIdx)] = ...
      repBenchmark.testDetector(detector, tf, imageAPath,imageBPath);
    
    [a b matchScore(detectorIdx,imageIdx) numMatches(detectorIdx,imageIdx)] = ...
      kmBenchmark.testDetector(detector, tf, imageAPath,imageBPath);
  end
end



%% Show scores

printScores(detectors, repeatability.*100, 'Detectors Repeatability');
figure(1); clf; plotScores(detectors, dataset, repeatability.*100, ...
 'Detectors Repeatability', 'Number of correspondences');

printScores(detectors, numCorresp, 'Number of correspondences');
figure(2); clf; plotScores(detectors, dataset, numCorresp, ...
 'Number of correspondences', 'Number of correspondences');


%% Helper functions

function printScores(detectors, scores, name, outFile)
  % PRINTSCORES
  % Print the scores measured in the unified format to the standard 
  % output. If outFile defined, save the results to a file as well.
  numDetectors = numel(detectors);
  saveResults = nargin > 3 && ~isempty(outFile);

  if saveResults
    helpers.vl_xmkdir(fileparts(outFile));
    fH = fopen(outFile,'w');
    fidOut = [1 fH];
  else
    fidOut = 1;
  end

  maxNameLen = 0;
  detNames = cell(numDetectors,1);
  for k = 1:numDetectors
    detNames{k} = detectors{k}.detectorName;
    maxNameLen = max(maxNameLen,length(detNames{k}));
  end

  maxNameLen = max(length('Method name'),maxNameLen);
  printf_lst(fidOut,strcat('\nPriting ', name,':\n'));
  formatString = ['%' sprintf('%d',maxNameLen) 's:'];

  printf_lst(fidOut,formatString,'Method name');
  for k = 1:size(scores,2)
    printf_lst(fidOut,'\tImg#%02d',k);
  end
  printf_lst(fidOut,'\n');

  for k = 1:numDetectors
    printf_lst(fidOut,formatString,detNames{k});
    for l = 1:size(scores,2)
      printf_lst(fidOut,'\t%6s',sprintf('%.2f',scores(k,l)));
    end
    printf_lst(fidOut,'\n');
  end

  if saveResults
    fclose(fH);
  end

  function printf_lst(fids,format,varargin)
  % printf_lst
  % Helper extending printf to more outputs.
  % Parameters:
  %   fids    Array of output file idxs
  %   format, varargin See fprintf.
  for m = 1:numel(fids)
    fprintf(fids(m),format,varargin{:});
  end
  end

end

function plotScores(detectors, dataset, score, titleText, yLabel, outFile)
  % PLOTSCORES
  % Plot the scores into unified figure number figureNum. If 
  % opts.SaveResults is true, save the figure to opts.SaveDir/outFile
  %
  % Parameters:
  if isempty(score)
    warning('No scores to plot.');
    return
  end

  saveResults = nargin > 5 && ~isempty(outFile);

  xstart = max([find(sum(score,1) == 0, 1) + 1 1]);

  xend = size(score,2);
  xLabel = dataset.imageNamesLabel;
  xTicks = dataset.imageNames;
  plot(xstart:xend,score(:,xstart:xend)','linewidth', 3) ; hold on ;
  ylabel(yLabel) ;
  xlabel(xLabel);
  set(gca,'XTick',xstart:1:xend);
  set(gca,'XTickLabel',xTicks);
  title(titleText);
  set(gca,'xtick',1:size(score,2));

  maxScore = max([max(max(score)) 1]);
  meanEndValue = mean(score(:,xend));
  legendLocation = 'SouthEast';
  if meanEndValue < maxScore/2
    legendLocation = 'NorthEast';
  end

  legendStr = cell(1,numel(detectors));
  for m = 1:numel(detectors) 
    legendStr{m} = detectors{m}.detectorName; 
  end
  legend(legendStr,'Location',legendLocation);
  grid on ;
  axis([xstart xend 0 maxScore]);

  if saveResults
    helpers.vl_xmkdir(fileparts(outFile));
    fprintf('\nSaving figure as eps graphics: %s\n',outFile);
    print('-depsc2', [outFile '.eps']);
    fprintf('Saving figure as matlab figure to: %s\n',figFile);
    saveas(gca,outFile,'fig');
  end
end

end
