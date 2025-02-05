local cd_hooks = require("cd-project.hooks")
local repo = require("cd-project.project-repo")
local utils = require("cd-project.utils")

---@return string|nil
local function find_project_dir()
	local found = vim.fs.find(
		vim.g.cd_project_config.project_dir_pattern,
		{ upward = true, stop = vim.loop.os_homedir(), path = vim.fs.dirname(vim.fn.expand("%:p")) }
	)

	if #found == 0 then
		return vim.loop.os_homedir()
	end

	local project_dir = vim.fs.dirname(found[1])

	if not project_dir or project_dir == "." or project_dir == "" or project_dir == " " then
		project_dir = string.match(vim.fn.execute("pwd"), "^%s*(.-)%s*$")
	end

	if not project_dir or project_dir == "." or project_dir == "" or project_dir == " " then
		return nil
	end

	return project_dir
end

---@return string[]
local function get_project_paths()
	local projects = repo.get_projects()
	local paths = {}
	for _, value in ipairs(projects) do
		table.insert(paths, value.path)
	end
	return paths
end

---@return string[]
local function get_project_names()
	local projects = repo.get_projects()
	local path_names = {}
	for _, value in ipairs(projects) do
		table.insert(path_names, value.name)
	end
	return path_names
end

---@param dir string
local function cd_project(dir)
	vim.g.cd_project_last_project = vim.g.cd_project_current_project
	vim.g.cd_project_current_project = dir
	vim.fn.execute("cd " .. dir)

	local hooks = cd_hooks.get_hooks(vim.g.cd_project_config.hooks, dir, "AFTER_CD")
	for _, hook in ipairs(hooks) do
		hook(dir)
	end
end

---@param path string
---@param name? string
---@param desc? string|nil
---@return CdProject.Project|nil
local function build_project_obj(path, name, desc)
	local normalized_path = vim.fn.expand(path)
	if vim.fn.isdirectory(normalized_path) == 0 then
		return utils.log_error(normalized_path .. " is not a directory")
	end

	return {
		path = normalized_path,
		name = name or utils.get_tail_of_path(normalized_path),
		desc = desc,
	}
end

---@param project CdProject.Project
local function add_project(project)
	local projects = repo.get_projects()

	if vim.tbl_contains(get_project_paths(), project.path) then
		return vim.notify("Project already exists: " .. project.path)
	end

	table.insert(projects, project)
	repo.write_projects(projects)
	vim.notify("Project added: \n" .. project.path)
end

local function add_current_project()
	local project_dir = find_project_dir()

	if not project_dir then
		return utils.log_err("Can't find project path of current file")
	end

	local project = build_project_obj(project_dir)

	if not project then
		return
	end

	add_project(project)
end

local function back()
	local last_project = vim.g.cd_project_last_project
	if not last_project then
		vim.notify("Can't find last project. Haven't switch project yet.")
	end
	cd_project(last_project)
end

return {
	cd_project = cd_project,
	build_project_obj = build_project_obj,
	get_project_paths = get_project_paths,
	get_project_names = get_project_names,
	add_current_project = add_current_project,
	add_project = add_project,
	back = back,
	find_project_dir = find_project_dir,
}
