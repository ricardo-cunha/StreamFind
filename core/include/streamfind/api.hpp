#pragma once

#include <string_view>

#include "streamfind/project.hpp"

namespace streamfind::api {

/** @brief Project operations exposed to command-line and language adapters. */
enum class ProjectCommand {
    create,
    describe,
    workflow_get,
    workflow_set,
    workflow_validate,
    validate,
    domain_get,
    method_list,
    method_execute,
    copy,
    execute,
    metadata_get,
    metadata_set,
    cache_get,
    cache_delete,
    cache_size,
    audit_get,
    close,
};

/** @brief Convert a command name to a ProjectCommand. */
STREAMFIND_CORE_API ProjectCommand command_from_string(std::string_view name);

/**
 * @brief Execute one JSON request against a Project.
 *
 * Requests use `database_path` and `project_id` to select a project. Commands
 * that modify a workflow additionally require a `workflow` JSON value.
 * Results are JSON objects suitable for direct CLI output.
 *
 * @param command Project operation to execute.
 * @param request JSON request object.
 * @param registry Registry used for workflow validation and execution.
 * @return JSON command result.
 * @throws Error if the request or Project operation is invalid.
 */
STREAMFIND_CORE_API Json run(ProjectCommand command, const Json &request,
                              const MethodRegistry &registry = methods());

}
