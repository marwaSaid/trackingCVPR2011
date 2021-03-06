function [featureSet, scoreSet] = extractDeepFeatures( imageList )
% extract deep learning features from the trained model
%   imgList: the absoluate location of images
% the CNN model
addpath('/data/vision/torralba/datasetbias/caffe-rcnn-release/matlab/caffe');

%nClass = 1000;
%model_file = '/data/vision/torralba/datasetbias/caffe-rcnn-release/examples/imagenet/caffe_reference_imagenet_model';
%model_def_file = '/data/vision/torralba/small-projects/bolei_deep/caffe/imagenet_deploy.prototxt';

nClass = 397;
model_def_file = '/data/vision/torralba/gigaSUN/deeplearning/fine_tune/PLACES_sun397_deploy.prototxt';
model_file = '/data/vision/torralba/gigaSUN/deeplearning/fine_tune/nonstandard_PLACES_sun397_trainval_iter_40000';



if exist(model_file, 'file') == 0
    error('You need a network model file');
end
caffe('init', model_def_file, model_file);
caffe('set_mode_cpu');
caffe('set_phase_test');
%caffe('set_device',1); % apparently if you use cpu instead of gpu above, you need to uncomment out this line

d = load('/data/vision/torralba/small-projects/bolei_deep/caffe/ilsvrc_2012_mean.mat');
IMAGE_MEAN = d.image_mean;
IMAGE_DIM = 256;
CROPPED_DIM = 227;

nImgs = numel(imageList);
featureSet = zeros(nImgs,4096);
scoreSet = zeros(nImgs,nClass);
batch_size = 256;
batch_padding = batch_size - mod(nImgs, batch_size);
num_batches = ceil(nImgs / batch_size);
IMAGE_MEAN = imresize(IMAGE_MEAN,[227 227]);

if matlabpool('size')==0
    try
        matlabpool
    catch e
    end
end

for curBatchID=1:num_batches
    [imBatch] = generateBatch( imageList, curBatchID, batch_size, num_batches, IMAGE_MEAN);    
    scores = caffe('forward', {imBatch});
    response = caffe('get_all_layers');
    scores = reshape(scores{1}, [nClass batch_size])';
    %scores = reshape(scores{1}, [109 batch_size]);
    featureFC7 = squeeze(response{13})';
    curStartIDX = (curBatchID-1)*batch_size+1;
    if curBatchID == num_batches
        curEndIDX = nImgs;
    else
        curEndIDX = curBatchID*batch_size;
    end
    featureSet(curStartIDX:curEndIDX,:) =  featureFC7(1:curEndIDX-curStartIDX+1,:);
    scoreSet(curStartIDX:curEndIDX,:) =  scores(1:curEndIDX-curStartIDX+1,:);
    disp([num2str(curBatchID) '/' num2str(num_batches)]);
end   

end

function [imBatch] = generateBatch( images, curBatchID, batch_size, num_batches, image_mean)
curStartIDX = (curBatchID-1)*batch_size+1;
if curBatchID == num_batches
    curEndIDX = numel(images);
else
    curEndIDX = curBatchID*batch_size;
end
IMAGE_DIM = 227;
imBatch = zeros(IMAGE_DIM, IMAGE_DIM, 3, batch_size, 'single');

nIter = curEndIDX-curStartIDX+1;

parfor i=1:nIter
    try 
        im = imread(images{i+curStartIDX-1,1});
    catch exception
        disp(images{i+curStartIDX-1,1})
    end
    if size(im,3)==1
        im = repmat(im,[1 1 3]);
    end     
    im = single(im);
    im = imresize(im, [IMAGE_DIM IMAGE_DIM], 'bilinear');
    im = im(:,:,[3 2 1]) - image_mean;
    imBatch(:,:,:,i) = permute(im, [2 1 3]);
end


end
