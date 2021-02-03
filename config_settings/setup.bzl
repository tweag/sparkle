
def _config_settings_impl(repository_ctx):
    ghc_version = repository_ctx.os.environ.get("GHC_VERSION", default = "8.10.2")
    repository_ctx.file(
        "BUILD",
        content = """exports_files(["info.bzl"])""",
        executable = False,
    )
    repository_ctx.file(
        "info.bzl",
        content = 'ghc_version = "{}"'.format(ghc_version),
        executable = False,
    )

config_settings = repository_rule(
    implementation = _config_settings_impl,
    attrs = {},
    environ = ["GHC_VERSION"],
)
