local httpService = game:GetService('HttpService');

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings';
	SaveManager.SubFolder = '';
	SaveManager.Ignore = {};
	SaveManager.Library = nil;
	SaveManager.UseLoadingOrder = false;
	SaveManager.LoadingOrder = {};
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object)
				return { type = 'Toggle', idx = idx, value = object.Value };
			end,
			Load = function(idx, data)
				local object = SaveManager.Library.Toggles[idx];
				if object and object.Value ~= data.value then
					object:SetValue(data.value);
				end;
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) };
			end,
			Load = function(idx, data)
				local object = SaveManager.Library.Options[idx];
				if object and object.Value ~= data.value then
					object:SetValue(data.value);
				end;
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi };
			end,
			Load = function(idx, data)
				local object = SaveManager.Library.Options[idx];
				if object and object.Value ~= data.value then
					object:SetValue(data.value);
				end;
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency };
			end,
			Load = function(idx, data)
				if SaveManager.Library.Options[idx] then
					SaveManager.Library.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency);
				end;
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value, modifiers = object.Modifiers };
			end,
			Load = function(idx, data)
				if SaveManager.Library.Options[idx] then
					SaveManager.Library.Options[idx]:SetValue({ data.key, data.mode, data.modifiers });
				end;
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value };
			end,
			Load = function(idx, data)
				local object = SaveManager.Library.Options[idx];
				if object and object.Value ~= data.text and type(data.text) == 'string' then
					SaveManager.Library.Options[idx]:SetValue(data.text);
				end;
			end,
		},
	};

	function SaveManager:SetLibrary(library)
		self.Library = library;
	end;

	function SaveManager:SetLoadingOrder(enabled, order)
		self.UseLoadingOrder = enabled;

		if typeof(order) == 'table' then
			self.LoadingOrder = order;
		end;
	end;

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true;
		end;
	end;

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree();
	end;

	function SaveManager:SetSubFolder(folder)
		self.SubFolder = folder;
		self:BuildFolderTree();
	end;

	function SaveManager:CheckSubFolder(createFolder)
		if typeof(self.SubFolder) ~= 'string' or self.SubFolder == '' then return false; end;

		if createFolder == true then
			if not isfolder(self.Folder .. '/settings/' .. self.SubFolder) then
				makefolder(self.Folder .. '/settings/' .. self.SubFolder);
			end;
		end;

		return true;
	end;

	function SaveManager:GetPaths()
		local paths = {};

		local parts = self.Folder:split('/');
		for idx = 1, #parts do
			local path = table.concat(parts, '/', 1, idx);
			if not table.find(paths, path) then paths[#paths + 1] = path; end;
		end;

		paths[#paths + 1] = self.Folder .. '/themes';
		paths[#paths + 1] = self.Folder .. '/settings';

		if self:CheckSubFolder(false) then
			local subFolder = self.Folder .. '/settings/' .. self.SubFolder;
			parts = subFolder:split('/');

			for idx = 1, #parts do
				local path = table.concat(parts, '/', 1, idx);
				if not table.find(paths, path) then paths[#paths + 1] = path; end;
			end;
		end;

		return paths;
	end;

	function SaveManager:BuildFolderTree()
		local paths = self:GetPaths();

		for i = 1, #paths do
			local str = paths[i];
			if not isfolder(str) then
				makefolder(str);
			end
		end;
	end;

	function SaveManager:CheckFolderTree()
		if isfolder(self.Folder) then return; end;
		SaveManager:BuildFolderTree();

		task.wait(0.1);
	end;

	function SaveManager:Save(name)
		if not name then
			return false, 'no config file is selected';
		end;
		SaveManager:CheckFolderTree();

		local fullPath = self.Folder .. '/settings/' .. name .. '.json';
		if SaveManager:CheckSubFolder(true) then
			fullPath = self.Folder .. '/settings/' .. self.SubFolder .. '/' .. name .. '.json';
		end;

		local data = {
			objects = {}
		};

		for idx, toggle in next, self.Library.Toggles do
			if toggle.Type and self.Parser[toggle.Type] and not self.Ignore[idx] then
				table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle));
			end
		end;

		for idx, option in next, self.Library.Options do
			if option.Type and self.Parser[option.Type] and not self.Ignore[idx] then
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option));
			end
		end;

		local success, encoded = pcall(httpService.JSONEncode, httpService, data);
		if not success then
			return false, 'failed to encode data';
		end;

		writefile(fullPath, encoded);
		return true;
	end;

	function SaveManager:Load(name)
		if not name then
			return false, 'no config file is selected';
		end;
		SaveManager:CheckFolderTree();

		local file = self.Folder .. '/settings/' .. name .. '.json';
		if SaveManager:CheckSubFolder(true) then
			file = self.Folder .. '/settings/' .. self.SubFolder .. '/' .. name .. '.json';
		end;

		if not isfile(file) then return false, 'invalid file'; end;

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file));
		if not success then return false, 'decode error'; end;

		if self.UseLoadingOrder == true and typeof(self.LoadingOrder) == 'table' then
			table.sort(decoded.objects, function(a, b)
				local aIndex = table.find(self.LoadingOrder, a.type) or math.huge;
				local bIndex = table.find(self.LoadingOrder, b.type) or math.huge;
				return aIndex < bIndex;
			end);
		end;

		for _, option in decoded.objects do
			if option.type and self.Parser[option.type] and not self.Ignore[option.idx] then
				task.spawn(self.Parser[option.type].Load, option.idx, option);
			end
		end;

		return true;
	end;

	function SaveManager:Delete(name)
		if not name then
			return false, 'no config file is selected';
		end;

		local file = self.Folder .. '/settings/' .. name .. '.json';
		if SaveManager:CheckSubFolder(true) then
			file = self.Folder .. '/settings/' .. self.SubFolder .. '/' .. name .. '.json';
		end;

		if not isfile(file) then return false, 'invalid file'; end;

		local success = pcall(delfile, file);
		if not success then return false, 'delete file error'; end;

		return true;
	end;

	function SaveManager:RefreshConfigList()
		local success, data = pcall(function()
			SaveManager:CheckFolderTree();

			local list = {};
			local out = {};

			if SaveManager:CheckSubFolder(true) then
				list = listfiles(self.Folder .. '/settings/' .. self.SubFolder);
			else
				list = listfiles(self.Folder .. '/settings');
			end;
			if typeof(list) ~= 'table' then list = {}; end;

			for i = 1, #list do
				local file = list[i];
				if file:sub(-5) == '.json' then
					local pos = file:find('.json', 1, true);
					local start = pos;

					local char = file:sub(pos, pos);
					while char ~= '/' and char ~= '\\' and char ~= '' do
						pos = pos - 1;
						char = file:sub(pos, pos);
					end;

					if char == '/' or char == '\\' then
						table.insert(out, file:sub(pos + 1, start - 1));
					end;
				end;
			end;

			return out;
		end);

		if not success then
			if self.Library then
				self.Library:Notify('Failed to load config list: ' .. tostring(data));
			else
				warn('Failed to load config list: ' .. tostring(data));
			end;

			return {};
		end;

		return data;
	end;

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({
			'BackgroundColor', 'MainColor', 'AccentColor', 'OutlineColor', 'FontColor', -- themes
			'ThemeManager_ThemeList', 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		});
	end;

	-- // Autoload \\ --
	function SaveManager:GetAutoloadConfig()
		SaveManager:CheckFolderTree();

		local autoLoadPath = self.Folder .. '/settings/autoload.txt';
		if SaveManager:CheckSubFolder(true) then
			autoLoadPath = self.Folder .. '/settings/' .. self.SubFolder .. '/autoload.txt';
		end;

		if isfile(autoLoadPath) then
			local successRead, name = pcall(readfile, autoLoadPath);
			if not successRead then
				return 'none';
			end;

			name = tostring(name);
			return name == '' and 'none' or name;
		end;

		return 'none';
	end;

	function SaveManager:LoadAutoloadConfig()
		SaveManager:CheckFolderTree();

		local autoLoadPath = self.Folder .. '/settings/autoload.txt';
		if SaveManager:CheckSubFolder(true) then
			autoLoadPath = self.Folder .. '/settings/' .. self.SubFolder .. '/autoload.txt';
		end;

		if isfile(autoLoadPath) then
			local successRead, name = pcall(readfile, autoLoadPath);
			if not successRead then
				self.Library:Notify('Failed to load autoload config: write file error');
				return;
			end;

			local success, err = self:Load(name);
			if not success then
				self.Library:Notify('Failed to load autoload config: ' .. err);
				return;
			end;

			self.Library:Notify(string.format('Auto loaded config %q', name));
		end;
	end;

	function SaveManager:SaveAutoloadConfig(name)
		SaveManager:CheckFolderTree();

		local autoLoadPath = self.Folder .. '/settings/autoload.txt';
		if SaveManager:CheckSubFolder(true) then
			autoLoadPath = self.Folder .. '/settings/' .. self.SubFolder .. '/autoload.txt';
		end;

		local success = pcall(writefile, autoLoadPath, name);
		if not success then return false, 'write file error'; end;

		return true, '';
	end;

	function SaveManager:DeleteAutoLoadConfig()
		SaveManager:CheckFolderTree();

		local autoLoadPath = self.Folder .. '/settings/autoload.txt';
		if SaveManager:CheckSubFolder(true) then
			autoLoadPath = self.Folder .. '/settings/' .. self.SubFolder .. '/autoload.txt';
		end;

		local success = pcall(delfile, autoLoadPath);
		if not success then return false, 'delete file error'; end;

		return true, '';
	end;

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'SaveManager:BuildConfigSection -> Must set SaveManager.Library');

		local section = tab:AddRightGroupbox('Configuration');

		section:AddInput('SaveManager_ConfigName', { Text = 'Config name' });
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true });

		section:AddDivider();

		section:AddButton('Create config', function()
			local name = self.Library.Options.SaveManager_ConfigName.Value;

			if name:gsub(' ', '') == '' then
				self.Library:Notify('Invalid config name (empty)', 2);
				return;
			end;

			local success, err = self:Save(name);
			if not success then
				self.Library:Notify('Failed to create config: ' .. err);
				return;
			end;

			self.Library:Notify(string.format('Created config %q', name));

			self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList());
			self.Library.Options.SaveManager_ConfigList:SetValue(nil);
		end):AddButton('Load config', function()
			local name = self.Library.Options.SaveManager_ConfigList.Value;

			local success, err = self:Load(name);
			if not success then
				self.Library:Notify('Failed to load config: ' .. err);
				return;
			end;

			self.Library:Notify(string.format('Loaded config %q', name));
		end);

		section:AddButton('Overwrite config', function()
			local name = self.Library.Options.SaveManager_ConfigList.Value;

			local success, err = self:Save(name);
			if not success then
				self.Library:Notify('Failed to overwrite config: ' .. err);
				return;
			end;

			self.Library:Notify(string.format('Overwrote config %q', name));
		end);

		section:AddButton('Delete config', function()
			local name = self.Library.Options.SaveManager_ConfigList.Value;

			local success, err = self:Delete(name);
			if not success then
				self.Library:Notify('Failed to delete config: ' .. err);
				return;
			end;

			self.Library:Notify(string.format('Deleted config %q', name));
			self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList());
			self.Library.Options.SaveManager_ConfigList:SetValue(nil);
		end);

		section:AddButton('Refresh list', function()
			self.Library.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList());
			self.Library.Options.SaveManager_ConfigList:SetValue(nil);
		end);

		section:AddButton('Set as autoload', function()
			local name = self.Library.Options.SaveManager_ConfigList.Value;

			local success, err = self:SaveAutoloadConfig(name);
			if not success then
				self.Library:Notify('Failed to set autoload config: ' .. err);
				return;
			end;

			self.Library:Notify(string.format('Set %q to auto load', name));
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name);
		end);

		section:AddButton('Reset autoload', function()
			local success, err = self:DeleteAutoLoadConfig();
			if not success then
				self.Library:Notify('Failed to reset autoload config: ' .. err);
				return;
			end;

			self.Library:Notify('Set autoload to none');
			SaveManager.AutoloadLabel:SetText('Current autoload config: none');
		end);

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: ' .. self:GetAutoloadConfig(), true);

		-- Build Cloud Upload section directly below Configuration on the right side
		self:BuildUploadSection(tab);

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' });
	end;

	-- // Cloud / Store Config Upload System \\ --
	local STORE_URL = 'https://config-hub--z1bje.replit.app/api';
	local RATE_FILE = 'creepcc/entities/zone_last_upload.txt';
	local HWID_FILE = 'creepcc/entities/zone_hwid.txt';

	local function ensureDirectories()
		if not isfolder('creepcc') then pcall(makefolder, 'creepcc'); end;
		if not isfolder('creepcc/entities') then pcall(makefolder, 'creepcc/entities'); end;
	end;

	local function execRequest(options)
		local fn = (syn and syn.request) or (http and http.request) or (type(request) == 'function' and request) or nil;
		if not fn then return nil; end;
		local ok, res = pcall(fn, options);
		return ok and res or nil;
	end;

	local function storePost(path, body)
		local res = execRequest({
			Url = STORE_URL .. path,
			Method = 'POST',
			Headers = { ['Content-Type'] = 'application/json' },
			Body = httpService:JSONEncode(body),
		});
		if res then return res.StatusCode, res.Body; end;
		return nil, nil;
	end;

	local function getHWID()
		ensureDirectories();
		if isfile(HWID_FILE) then
			local cached = readfile(HWID_FILE);
			if cached and #cached > 4 then return cached; end;
		end;
		local id = (type(syn) == 'table' and type(syn.get_hwid) == 'function' and syn.get_hwid())
			or (type(get_hwid) == 'function' and get_hwid())
			or tostring(game:GetService('Players').LocalPlayer.UserId);
		pcall(function() writefile(HWID_FILE, tostring(id)); end);
		return tostring(id);
	end;

	local HOUR = 3600;
	local function getSecondsUntilNextUpload()
		ensureDirectories();
		if not isfile(RATE_FILE) then return 0; end;
		local lastTime = tonumber(readfile(RATE_FILE));
		if not lastTime then return 0; end;
		local elapsed = os.time() - lastTime;
		return elapsed >= HOUR and 0 or (HOUR - elapsed);
	end;

	local function markUploadTime()
		ensureDirectories();
		pcall(function() writefile(RATE_FILE, tostring(os.time())); end);
	end;

	function SaveManager:BuildUploadSection(tab)
		assert(self.Library, 'Must set SaveManager.Library');

		local UploadGroup = tab:AddRightGroupbox('Upload');

		UploadGroup:AddInput('UploadName', {
			Text = 'Config Name';
			Default = '';
			Placeholder = 'e.g. my_rage_config';
		});
		UploadGroup:AddInput('UploadAuthor', {
			Text = 'Your Name';
			Default = '';
			Placeholder = 'your username';
		});
		UploadGroup:AddInput('UploadDesc', {
			Text = 'Description';
			Default = '';
			Placeholder = 'optional';
		});

		local localCfgDropdown = nil;
		local function refreshLocalConfigs()
			local cfgs = self:RefreshConfigList() or {};
			if localCfgDropdown then
				localCfgDropdown:SetValues(cfgs);
				if #cfgs > 0 then
					localCfgDropdown:SetValue(cfgs[1]);
				end;
			end;
		end;

		localCfgDropdown = UploadGroup:AddDropdown('UploadLocalDropdown', {
			Text = 'Select Config';
			Default = 1;
			Values = self:RefreshConfigList() or { '' };
		});

		UploadGroup:AddButton('Refresh Configs', function()
			refreshLocalConfigs();
			self.Library:Notify('Local config list refreshed');
		end);

		UploadGroup:AddButton('Upload to Store', function()
			local selectedCfg = Options.UploadLocalDropdown.Value or '';
			local name = Options.UploadName.Value or '';
			local author = Options.UploadAuthor.Value or '';
			local desc = Options.UploadDesc.Value or '';

			if selectedCfg == '' then
				self.Library:Notify('Select a local config first');
				return;
			end;
			if name == '' then
				self.Library:Notify('Enter a config name');
				return;
			end;
			if author == '' then
				self.Library:Notify('Enter your name');
				return;
			end;

			local wait = getSecondsUntilNextUpload();
			if wait > 0 then
				local mins = math.ceil(wait / 60);
				self.Library:Notify(string.format('Rate limited — wait %d more minute%s', mins, mins == 1 and '' or 's'));
				return;
			end;

			local filePath = self.Folder .. '/settings/' .. selectedCfg .. '.json';
			if SaveManager:CheckSubFolder(true) then
				filePath = self.Folder .. '/settings/' .. self.SubFolder .. '/' .. selectedCfg .. '.json';
			end;
			if not isfile(filePath) then
				self.Library:Notify('Config file not found: ' .. selectedCfg);
				return;
			end;

			local ok2, configData = pcall(function() return httpService:JSONDecode(readfile(filePath)); end);
			if not ok2 or not configData then
				self.Library:Notify('Failed to read config file');
				return;
			end;

			local status, raw = storePost('/configs', {
				name = name;
				author = author;
				description = desc;
				hwid = getHWID();
				data = configData;
			});

			if not raw then
				self.Library:Notify('Upload failed — no response');
				return;
			end;

			local ok3, decoded = pcall(function() return httpService:JSONDecode(raw); end);
			if status == 429 then
				self.Library:Notify(ok3 and decoded and decoded.error or 'Rate limited');
				return;
			end;

			if status == 201 and ok3 and decoded and decoded.id then
				markUploadTime();
				self.Library:Notify(string.format('Uploaded! ID %d — share with friends', decoded.id));
			else
				self.Library:Notify(ok3 and decoded and decoded.error or 'Upload failed');
			end;
		end);

		UploadGroup:AddButton('Copy Config Hub URL', function()
			local fn = setclipboard or toclipboard;
			if fn then
				fn('https://config-hub--z1bje.replit.app');
				self.Library:Notify('Copied Config Hub URL to clipboard!');
			else
				self.Library:Notify('Your executor does not support clipboard copying.');
			end;
		end);

		SaveManager:SetIgnoreIndexes({ 'UploadName', 'UploadAuthor', 'UploadDesc', 'UploadLocalDropdown' });

		task.spawn(function()
			task.wait(0.5);
			pcall(refreshLocalConfigs);
		end);
	end;

	function SaveManager:BuildFullConfigTab(window)
		local ConfigsTab = window:AddTab('Configs');
		self:BuildUploadSection(ConfigsTab);
		self:BuildConfigSection(ConfigsTab);
		return ConfigsTab;
	end;

	SaveManager:BuildFolderTree();
end;

return SaveManager;
