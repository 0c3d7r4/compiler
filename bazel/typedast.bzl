# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Creates a TypedAST.List file from JS srcs

Args:
    srcs: (*.js)
    compiler: (*.jar) A version of the compiler to use for generating the file.

Returns:
    The TypedAST.List file
"""

def _typedast_impl(ctx):
    name = ctx.attr.name
    if not name.endswith("_typedast"):
        fail("name must end with _typedast")

    typedast_file = ctx.actions.declare_file(name[:-len("_typedast")] + ".typedast")
    typedast_gz_file = ctx.actions.declare_file(name[:-len("_typedast")] + ".typedast.gz")

    compiler_outputs = []
    compiler_inputs = []
    args = ctx.actions.args()

    compiler_inputs.extend(ctx.files._jdk)
    args.add_all([
        "--checks_only",
        "--strict_mode_input",
        "--env=CUSTOM",
        "--language_out=ES_NEXT",
        "--inject_libraries=false",
        "--jscomp_error=checkTypes",
        "--jscomp_off=uselessCode",
    ])
    args.add(typedast_gz_file, format = "--typed_ast_output_file__INTENRNAL_USE_ONLY=%s")
    compiler_outputs.append(typedast_gz_file)
    args.add_all(ctx.files.srcs, format_each = "--js=%s")
    compiler_inputs.extend(ctx.files.srcs)

    ctx.actions.run(
        outputs = compiler_outputs,
        inputs = compiler_inputs,
        executable = ctx.executable.compiler,
        arguments = [args],
        mnemonic = "TypedAST",
    )

    ctx.actions.run_shell(
        outputs = [typedast_file],
        inputs = [typedast_gz_file],
        command = "gunzip -c '%s' > '%s'" % (typedast_gz_file.path, typedast_file.path),
    )

    return [
        DefaultInfo(
            files = depset([typedast_file]),
        ),
    ]

typedast = rule(
    implementation = _typedast_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".js"], mandatory = True),
        "compiler": attr.label(
            mandatory = True,
            executable = True,
            cfg = "exec",
        ),
        "_jdk": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
            cfg = "exec",
        ),
    },
)
