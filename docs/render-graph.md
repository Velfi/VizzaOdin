# Compiled Render Graph

The Vulkan adapter registers resources, pass callbacks, reads, writes, and
external side effects. Pass names are diagnostic strings; product modes are not
encoded in a fixed pass-kind enum.

Compilation validates handles and explicit dependencies, derives minimal
registration-order RAW/WAR/WAW edges, performs a deterministic topological
sort, and records barrier descriptions. Resource first/last use is measured in
compiled execution order. Compatible transient resources receive the same
physical slot only when their lifetimes do not overlap.

Compatibility includes resource kind, format, extent or byte size, and usage;
matching kind alone is insufficient. Hazard compilation is subresource-aware
for image mip and array-layer ranges, with zero counts denoting the whole
resource. A diagnostics snapshot exposes compile status and failure, compiled
pass order, barriers, logical lifetimes, and physical slot decisions.

Compiled topology is cached by active feature, the actual order-independent
preview-mode set (not merely its size), capture state, and target format.
Imported Vulkan handles and external initial state are resolved per frame. The
graph owns inter-pass synchronization; simulation callbacks own barriers
between dispatches inside one declared pass.

Cached resources contain no live Vulkan handles. Each frame supplies imported
image bindings with the current handle, layout, stage, and access state. Barrier
execution validates the observed old layout before transitioning the bound
image, updates its observed state, and verifies the final state against the
resource's last compiled use. Missing imported bindings fail execution before
submission.

Structural pass enablement is resolved before compilation. Disabled passes do
not participate in dependencies, hazards, barriers, execution order, or
resource lifetimes, and diagnostics expose their registration indices. Video
capture is a dedicated external readback pass shared by screenshots and video,
compiled between simulation
presentation and the late UI overlay only while capture is active. Its declared
`TRANSFER_SRC_OPTIMAL` read causes the graph to transition color output into
transfer source and back into color attachment use for the late overlay; the
capture callbacks record only copies and do not perform inter-pass layout
transitions. Screenshot intent is resolved before topology lookup, so periodic
or explicitly requested screenshots structurally enable this same pass.

Capture readbacks use physical buffers pooled by capture consumer and Vulkan
frame slot. Reuse occurs only after `vk_begin_frame` has waited for that slot's
fence. A buffer is retained while its capacity covers the current swapchain and
is replaced only when a larger target is required; backend destruction retires
the pool. This is the first validated physical transient-reuse path.

UI vertices are not graph transients: `Ui_Renderer` owns one persistently
mapped buffer per frame slot. The graph imports and binds the active slot each
frame, declares its host-write and vertex-read uses, and never assigns it a
logical alias slot. This keeps transient diagnostics limited to allocations
whose physical lifetime the graph actually controls.

Scene post-processing discovery is feature-registered. Applicable render
descriptors expose renderer-neutral blur settings to the shared present path;
the graph no longer switches on `App_Mode` to reach into simulation settings.
Features without graph-level post-processing leave the callback empty.

The swapchain and active feature output are graph-owned imported resources.
Acquire records the swapchain's external present state; compiled barriers
transition it to color attachment use before scene presentation, preserve color
visibility across late UI, and return it to present state afterward. After the
simulation pass, the active feature descriptor binds its actual output image or
buffer with the observed state. The graph then makes compute writes visible to
fragment or vertex consumption. Scratch resources used only between dispatches
remain inside the feature pass. Screenshot and video readback remain explicit
external side effects after the swapchain handoff.

Main-menu preview stepping and presentation, normal simulation stepping, and
normal presentation dispatch through the paired render feature registry.
Core graph passes contain no per-simulation fallback switches. Non-feature
screens use one shared clear/UI presentation path; registered simulations and
their previews can only enter through descriptor callbacks.
Preview preparation is descriptor-owned too, including feature-local uniform
uploads, descriptor refresh, and final image-state preparation before drawing.
There is no fallback mode switch, and supported preview counts are derived from
registered capabilities and callbacks rather than a fixed constant.

For the main menu, compilation adds one external feature-output resource for
each mode in the preview-set key. After preview stepping, the same descriptor
callbacks bind the preview instance's image or buffer. This gives every visible
preview its own compute-to-presentation dependency and prevents a cached graph
for one equal-sized preview combination from being reused for another.

Compiled transient slots have a backend-owned physical pool. At frame binding,
compatible vertex/index buffers and storage/sampled images with disjoint
compiled lifetimes share the slot selected by the compiler; incompatible shape,
format, usage, or kind changes retire and replace the allocation. Image slots
own their Vulkan image, memory, and view. Pool allocations are destroyed with
the render backend, and graph diagnostics report physical allocation and reuse
independently from externally owned screenshot/video readback pools.
Every transient logical resource receives an initial or alias-handoff barrier
at its first compiled use. Reused slots source that barrier from the prior
logical resource's final declared stage, access, and layout. Slot selection
checks all resources already assigned to the slot—not just the first compatible
resource—so an older completed lifetime cannot hide a newer overlapping one.
