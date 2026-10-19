platform "kernel-roc"
    requires {} { main! : {} => {} }
    exposes [Write]
    packages {}
    provides { "roc_main" : main_for_host! }
    hosted {
        "roc_write_string" : Host.write_string!,
    }
    targets: {
        inputs_dir: "targets-out/",
        x64elf: { inputs: ["libhost.a", app], output: Archive },
    }

import Host
import Write

main_for_host! : {} => {}
main_for_host! = |_| {
    Write.write!("Hello from Roc Platform on bare metal!\n")
    main!({})
}
