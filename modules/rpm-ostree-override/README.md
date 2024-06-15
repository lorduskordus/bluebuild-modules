# rpm-ostree-override Module

The `rpm-ostree-override` module allows replacing packages already included in the base image using `rpm-ostree override`.

The module first downloads the repository file from repository declared under `from-repo:` into `/etc/yum.repos.d/`. The magic string `%OS_VERSION%` is substituted with the current VERSION_ID (major Fedora version), which can be used, for example, for pulling correct versions of repositories from [Fedora's Copr](https://copr.fedorainfracloud.org/).

The module then replaces the packages declared under `packages:` using `rpm-ostree override replace`.

Lastly, the repository file is removed from `/etc/yum.repos.d/`.

The module can be used to replace packages from multiple repositories, check out the example configuration on how to do that.

### Example Configuration

```yaml
type: rpm-ostree-override
replace:
  - from-repo: https://repository1_URL.repo
    packages:
        - package1
        - package2
  - from-repo: https://repository2_URL.repo
    packages:
        - package3
        - package4
        - package5
```
