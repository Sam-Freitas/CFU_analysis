%Vanessa Silbar
%7/7/21, Image processing for bacteria colonies

% Sam Freitas
% 7/16/21 edited :D

warning('off', 'MATLAB:MKDIR:DirectoryExists');

clear all
close all force hidden

curr_path = pwd;
disp('Select Experiment')

img_dir_path = uigetdir(curr_path);

%set to 0 if you don't care about separating colonies
manually_separate = 1;

% crop the images if they are just kinda bad
crop_images = 1;

% export the masks 
export_masks = 1;

img_paths = dir(fullfile(img_dir_path, '*.png'));

disp(['Processing data for: ' img_dir_path])

[~,name] = fileparts(img_dir_path); %gets name of experiment/plate

exp_name = strings(1,length(img_paths));
img_name = strings(1,length(img_paths));
units_in_img = strings(1,length(img_paths));
img_num = zeros(1,length(img_paths));
major_radius = zeros(1,length(img_paths));
minor_radius = zeros(1,length(img_paths));
calculated_radius = zeros(1,length(img_paths));
avg_radius = zeros(1,length(img_paths));
img_num_colony = zeros(1,length(img_paths));
total_num_colony = zeros(1,length(img_paths));
area_data = zeros(1,length(img_paths));
units_per_pixel = zeros(1,length(img_paths));
area_in_units = zeros(1,length(img_paths));
colony_circularity_data = zeros(1,length(img_paths));
perimeter_data = zeros(1,length(img_paths));

count = 1;
se = strel('disk',30);

for i = 1:length(img_paths)
    
    % get image path
    this_img_path = fullfile(img_dir_path,img_paths(i).name);
    % read in image
    this_img = imread(this_img_path);
    % convert to grayscale
    data = rgb2gray(this_img); 
    
    % get ocr images
    ocr_pre_stats = regionprops(data==0,'Image');
    % extract image
    extracted_img = ocr_pre_stats.Image;
    
    % get OCR object
    ocr_obj = ocr(extracted_img,'TextLayout','Block');
    % extract text and trim it
    extracted_txt_full = strtrim(ocr_obj.Text);
    % get bounding box of words
    word_bb = ocr_obj.WordBoundingBoxes;
    % get w/y/w/h
    x = min(word_bb); x = x(1);
    y = min(word_bb); y = y(2);
    w = sum(word_bb); w = w(3)+10;
    h = max(word_bb); h = h(4);
    % get the scale line images
    scale_img = ~extracted_img;
    scale_img(y:y+h,x:x+w) = 0;
    % get scale line stats
    scale_stats = regionprops(scale_img,'BoundingBox');
    % get length of line
    length_scale_pixels = scale_stats.BoundingBox(3);
    
    % separate distance from units
    space_idx = strfind(extracted_txt_full,' ');
    extracted_txt_num = extracted_txt_full(1:space_idx-1);
    extracted_txt_units = extracted_txt_full(space_idx+1:end);
    
    extracted_num{i} = str2double(extracted_txt_num);
    extracted_unit{i} = extracted_txt_units;
    
    % get threshold
    thresh = mean2(data) + 1.5*std2(data);
    % get mask
    masked_data = bwareaopen(data > thresh,1000,4);
    
    if crop_images
        imshow(masked_data)
        title(img_paths(i).name,'Interpreter','none')
        
        dlg_choice_crop = questdlg({'Does this image need to be cropped?',...
            'If so crop the image with a double click and drag'},'Colonies','Yes','No','No');
        
        if isequal(dlg_choice_crop,'Yes')
            data = imcrop(data);
        end
        
        thresh = mean2(data) + 1.5*std2(data);
        % get mask
        masked_data = bwareaopen(data > thresh,1000,4);
        
    end
        
    if manually_separate
        % show mask
        imshow(masked_data);
        title(img_paths(i).name,'Interpreter','none')
        hold on
        
        dlg_choice = questdlg({'Do any colonies in this image need to be separated?',...
            'If so draw line between colonies'},'Colonies','Yes','No','No');
        
        clear ROI
        
        while isequal(dlg_choice,'Yes')
            
            clear ROI
            
            % draw to separate
            ROI= drawline;
            bw_ROI = ROI.createMask(masked_data);
            % thicken line
            thicc_bw_ROI = imgaussfilt(bw_ROI*5,3)>0;
            % remove thiccline
            masked_data = masked_data.*(~thicc_bw_ROI);
            
            dlg_choice = questdlg({'Do more colonies need to be separated?',...
                'If so draw line between colonies'},'Colonies','Yes','No','No');
        end
    end
    final_mask = imclearborder(masked_data,8);
    close all
    
    clear ROI
    % fill the masks
    Ifill = imfill(final_mask>0,'holes');
    % region props
    bw_stats = regionprops(Ifill,'Centroid','MajorAxisLength','MinorAxisLength','Area','Perimeter','Circularity');
    
    if export_masks
        mkdir('exported_images');
        mkdir(fullfile('exported_images',name));
        
        out_img_path = fullfile('exported_images',name,img_paths(i).name);        
        
        [boundary_pixels,this_label] = bwboundaries(Ifill,'noholes');
        
        rgb_label = label2rgb(this_label,'jet','k');
        
        for j = 1:length(bw_stats)
            rgb_label = insertText(rgb_label,bw_stats(j).Centroid,num2str(j),...
                'TextColor','w','BoxColor','g','FontSize',36);
        end
        
        imwrite(rgb_label,out_img_path)
        
    end
    
    % get stats
    for j = 1:length(bw_stats)
        exp_name(count) = string(name);
        img_name(count) = string(fullfile(img_paths(i).folder,img_paths(i).name));
        img_num(count) = i;
        total_num_colony(count) = count;
        img_num_colony(count) = j;
        major_radius(count) = bw_stats(j).MajorAxisLength/2;
        minor_radius(count) = bw_stats(j).MinorAxisLength/2;
        calculated_radius(count) = sqrt(bw_stats(j).Area/pi);
        avg_radius(count) = (bw_stats(j).MajorAxisLength/2 + bw_stats(j).MajorAxisLength/2 + sqrt(bw_stats(j).Area/pi))/3;
        area_data(count) = bw_stats(j).Area;
        
        perimeter_data(count) = bw_stats(j).Perimeter;
        
        colony_circularity_data(count) = (perimeter_data(count)^2) / (4*pi*area_data(count));
        
        units_in_img(count) = extracted_txt_units;
        
        units_per_pixel(count) = extracted_num{i}/length_scale_pixels;
        
        area_in_units(count) = area_data(count)*(units_per_pixel(count)^2);
        
        count = count + 1;
    end
    
end

csv_header = ["Sub Experiment Name","Image Path","Image Number",...
    "Total Colony Counter","Image Colony Counter"...
    "Major Radius","Minor Radius","Calculated Radius","Average Radius"...
    "Calculated Area sq pixels","Units","Scale Units/Pixel","Area in sq Units",...
    "Perimeter","Circularity"];

exp_table = [exp_name;img_name;img_num;total_num_colony;img_num_colony;major_radius;minor_radius;calculated_radius;...
    avg_radius;area_data;units_in_img;units_per_pixel;area_in_units;...
    perimeter_data;colony_circularity_data]';

for i = 1:size(exp_table,1)
    for j = 1:size(exp_table,2)
        final_table{i,j} = exp_table(i,j);
    end
end

T = cell2table(final_table,'VariableNames',csv_header);

output_csv_path = fullfile(img_dir_path,'data.csv');
disp(['Data output to ' output_csv_path])

writetable(T,output_csv_path);


