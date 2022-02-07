function visualize_raw_data_and_stimulus(sub_folder, main_folder, add_stimulus, is_color, frame_rate, avg_frame)
    arguments
        sub_folder (1,1) string;
        main_folder (1,1) string;
        add_stimulus (1,1) logical = true;
        is_color  = true; % false will create grayscale output (smaller in size)
        frame_rate (1,1) {mustBeNumeric}  = 100;  % 29.946 is original. Compressions doesn't work when frame rate is very high (but also undeeded)
        avg_frame (1,1) {mustBeNumeric}  =  2;  % 1 for no averaging
    end

    DIR       = fullfile(main_folder, sub_folder);
    folder_n  = "tiffs";  % this is the data folder name, as created by script
    vidName   = append("video_", num2str(frame_rate), "fps_avg", num2str(avg_frame));  % output file name (prefix)

    disp(append(DIR, ", color? ", num2str(is_color), ", with stim? ", num2str(add_stimulus), ", FR=", num2str(frame_rate), ", avg=", num2str(avg_frame)))

    stimulus_config = [];

    if add_stimulus
        load(fullfile(DIR, "thor_sync_data", "StimulusConfigWithTimestamp.mat"));
        vidName = append(vidName, "_with_stim");
    end

    %% Read names (sorted) - search all tiffs in folder, and regex the name to created sorted list
    file_names = dir(fullfile(DIR, folder_n, "*.tiff")); 
    name_path  = file_names(1).name;  
    file_names = strings(length(file_names), 1);
    for i = 1:length(file_names)
        file_names(i) = strrep(name_path, "_1.tiff", append("_", num2str(i), ".tiff"));  % use the name_path format, to replace only the number
    end
    disp(file_names)

    %% Write the video (while reading the tiffs) - few minutes run
    colorMap = [zeros(256,1), linspace(0,1,256)', zeros(256,1)];  % green, RGB
    video = create_video(DIR, vidName, frame_rate, is_color);
    open(video);

    add_f = 0;
    try  % Make sure to always close video, even if err occurs (not to be corrupted)
        for curr = file_names'
            disp(curr);
            tstack    = Tiff(fullfile(DIR, folder_n, curr), 'r');
            tiff_info = imfinfo(fullfile(DIR, folder_n, curr));
            n_frames  = length(tiff_info);
            for n = 1:avg_frame:n_frames  % loop frames read (didnt find way to read all stack at once, though it should be)
                img = read_next_img_with_avg(avg_frame, tiff_info, tstack, n, n_frames);
                img = uint8(img / 10); % scale to uint8 (color req. uint8 & the original 16bit looks gray)
                if is_color
                    img = ind2rgb(img, colorMap);
                end
                if ~isempty(stimulus_config)
                    img = add_metadata_stimulus(img, stimulus_config, n, add_f);
                end
                 writeVideo(video, img);  
            end
            add_f = add_f + n_frames;
        end
    catch err  % close vid and rethrow the error for debug
        close(video);
        rethrow(err);
    end
    close(video);
end

%% Help functions
function video = create_video(DIR, vidName, frmRate, is_color)
    % create_video return video-writer object, which is compressed/not
    % based on the frame rate
    
    if frmRate <= 170 && ispc  % above this, we should compress. Note that MPEG-4 compression has maximal FrameRate it can get (not sure what is the value)
        if is_color
            disp(fullfile(DIR, vidName + "_compressed_color.mp4"))
            video = VideoWriter(fullfile(DIR, vidName + "_compressed_color.mp4"),'MPEG-4');  % indexed avi is not compressed => we use mpeg + rgb
        else
            video = VideoWriter(fullfile(DIR, vidName + ".mp4"),'MPEG-4'); % compressed - 4 times better than default 'Motion JPEG'
        end
    else
        if ~ispc
	   disp("Linux matlab doesnt support MPEG codec (or any movie compression) without installation")
	end
        if is_color
            video = VideoWriter(fullfile(DIR, vidName + "_color.avi"));
        else
            video = VideoWriter(fullfile(DIR, vidName + ".avi")); % default 'Motion JPEG'
        end
    end

    video.Quality = 100;
    video.FrameRate = frmRate;
end

function img = read_next_img_with_avg(avg_frame, tiff_info, tstack, n, n_frames)
    % read_next_img_with_avg returns current image in tiff-stack, either
    % data as is or the average of <avg_frame> frames
    
    if avg_frame > 1  % can't read few images together, using for loop on avg
        imgs = nan([tiff_info(1,:).Height],[tiff_info(1,:).Width], avg_frame);
        for ind = 1:avg_frame
            imgs(:, :, ind) = tstack.read();
            if currentDirectory(tstack) + 1 <= n_frames
                % disp(currentDirectory(tstack))
                tstack.nextDirectory();
            else
                break;
            end
        end
        img = mean(imgs, 3);
    else
        img = tstack.read();
        if n < n_frames
            % disp(currentDirectory(tstack))
            tstack.nextDirectory();
        end
    end
end
function compress_avi_to_mp4(DIR, vidName)
    reader = VideoReader(fullfile(DIR, vidName + ".avi"));
    writer = VideoWriter(fullfile(DIR, vidName + "_compressed.mp4"), 'MPEG-4');
    writer.FrameRate = reader.FrameRate;
    open(writer);
    while hasFrame(reader)
       writeVideo(writer,readFrame(reader));
    end
    close(writer); delete(reader);
end

function combine_videos(DIR, file_names_from_dir_function, FrameRate)
    try
        writer = VideoWriter(fullfile(DIR, "combined.mp4"), 'MPEG-4');
        writer.FrameRate = FrameRate; open(writer); 
        for curr = file_names_from_dir_function'
            disp(curr)
            reader = VideoReader(fullfile(DIR, curr));
            while hasFrame(reader)
               writeVideo(writer,readFrame(reader));
            end
            delete(reader);
        end
    catch err  % close vid and rethrow the error for debug
       close(writer); 
       rethrow(err);
    end
    close(writer);
end

function img = add_metadata_stimulus(img, stimulus_config, i, j)
    frame_number = i + j;
    img = insertText(img, [0, 10], ['#' num2str(frame_number)], 'FontSize',18,...
        'TextColor','white', 'BoxColor','black');

    if frame_number < min(stimulus_config.frameNumberInData)  
        img = insertText(img, [200, 10], "Before stim", 'FontSize',18,...
            'TextColor','white', 'BoxColor','black');
    elseif frame_number > max(stimulus_config.frameNumberInData)  
        img = insertText(img, [200, 10], "After stim", 'FontSize',18,...
            'TextColor','white', 'BoxColor','black');
    else
        % Find the relevant row in the table 
        diffs = stimulus_config.frameNumberInData - frame_number; 
        diffs(diffs < 0) = NaN;  % negative = all lines before
        [~, r_i] = min(diffs);
        data_table = stimulus_config(r_i, :);

        if lower(string(data_table.exitCriteria)) == "distance"  % may have small bug here
            n_frames = stimulus_config.frameNumberInData(r_i + 1) - stimulus_config.frameNumberInData(r_i);
            all_dist = data_table.endX - data_table.startX;
            mov_x = ceil(all_dist / n_frames);  % approx. by how much to move x
            d_frames = frame_number - stimulus_config.frameNumberInData(r_i); % how many frames to move
            loc = [data_table.startX + d_frames * mov_x 20]; % dot location (y is hard coded at top)
            img = insertShape(img,'filledcircle', [loc 5],'LineWidth',2, 'Color', {'white'});
            img = insertText(img, [200, 10], append("", num2str(r_i - 1)), 'FontSize',18,...
                'TextColor','white', 'BoxColor','black');
        elseif lower(string(data_table.exitCriteria)) == "time"
            img = insertText(img, [200, 10], append("Time ", num2str(r_i - 1)), 'FontSize',18,...
                'TextColor','white', 'BoxColor','black');
            loc = [data_table.startX 20]; 
            img = insertShape(img,'filledcircle', [loc 5],'LineWidth',2, 'Color', {'white'});
        end
    end
end
