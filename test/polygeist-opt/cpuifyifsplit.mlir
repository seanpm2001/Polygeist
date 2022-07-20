// RUN: polygeist-opt --cpuify="method=distribute.mincut.ifhoist" --split-input-file %s | FileCheck %s

module {
  func.func private @use(%arg0: i32)
  func.func private @usei(%arg0: index)
  func.func private @get() -> i32
  func.func private @get2() -> i32
  func.func private @geti() -> index
  func.func private @geti2() -> index
  func.func @simple_if_split(%arg: i1, %amem: memref<i32>, %bmem : memref<i32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c9 = arith.constant 9 : index
    scf.parallel (%arg4) = (%c0) to (%c9) step (%c1) {
      func.call @usei(%arg4) : (index) -> ()
      scf.if %arg {
        %v = func.call @get() : () -> i32
        %alloc = memref.alloca() : memref<i32>
        memref.store %v, %alloc[] : memref<i32>
        "polygeist.barrier"(%arg4) : (index) -> ()
        %load = memref.load %alloc[] : memref<i32>
        func.call @use(%load) : (i32) -> ()
        func.call @use(%v) : (i32) -> ()
        scf.yield
      }
      func.call @usei(%arg4) : (index) -> ()
      scf.yield
    }
    return
  }
  func.func @simple_if_hoist(%arg: i1, %amem: memref<i32>, %bmem : memref<i32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c9 = arith.constant 9 : index
    scf.parallel (%arg4) = (%c0) to (%c9) step (%c1) {
      scf.if %arg {
        %v = func.call @get() : () -> i32
        %alloc = memref.alloca() : memref<i32>
        memref.store %v, %alloc[] : memref<i32>
        "polygeist.barrier"(%arg4) : (index) -> ()
        %load = memref.load %alloc[] : memref<i32>
        func.call @use(%load) : (i32) -> ()
        func.call @use(%v) : (i32) -> ()
        scf.yield
      }
      scf.yield
    }
    return
  }
  func.func @simple_if_split_i32(%arg: i1, %amem: memref<i32>, %bmem : memref<i32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c9 = arith.constant 9 : index
    scf.parallel (%arg4) = (%c0) to (%c9) step (%c1) {
      func.call @usei(%arg4) : (index) -> ()
      %res = scf.if %arg -> i32 {
        %v = func.call @get() : () -> i32
        "polygeist.barrier"(%arg4) : (index) -> ()
        func.call @use(%v) : (i32) -> ()
        scf.yield %v : i32
      } else {
        %v = func.call @get2() : () -> i32
        func.call @use(%v) : (i32) -> ()
        scf.yield %v : i32
      }
      func.call @use(%res) : (i32) -> ()
      scf.yield
    }
    return
  }
  //func.func @simple_if_split_index(%arg: i1, %amem: memref<i32>, %bmem : memref<i32>) attributes {llvm.linkage = #llvm.linkage<external>} {
  //  %c0 = arith.constant 0 : index
  //  %c1 = arith.constant 1 : index
  //  %c9 = arith.constant 9 : index
  //  scf.parallel (%arg4) = (%c0) to (%c9) step (%c1) {
  //    func.call @usei(%arg4) : (index) -> ()
  //    %res = scf.if %arg -> index {
  //      %v = func.call @geti() : () -> index
  //      "polygeist.barrier"(%arg4) : (index) -> ()
  //      func.call @usei(%v) : (index) -> ()
  //      scf.yield %v : index
  //    } else {
  //      %v = func.call @geti2() : () -> index
  //      func.call @usei(%v) : (index) -> ()
  //      scf.yield %v : index
  //    }
  //    func.call @usei(%res) : (index) -> ()
  //    scf.yield
  //  }
  //  return
  //}

}

// CHECK:  func.func @simple_if_split(%arg0: i1, %arg1: memref<i32>, %arg2: memref<i32>)
// CHECK-DAG:    %c0 = arith.constant 0 : index
// CHECK-DAG:    %c1 = arith.constant 1 : index
// CHECK-DAG:    %c9 = arith.constant 9 : index
// CHECK-NEXT:    call @usei(%c0) : (index) -> ()
// CHECK-NEXT:    scf.if %arg0 {
// CHECK-NEXT:      memref.alloca_scope  {
// CHECK-NEXT:        %0 = memref.alloca(%c9) : memref<?xi32>
// CHECK-NEXT:        %1 = memref.alloca(%c9) : memref<?xi32>
// CHECK-NEXT:        scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:          func.call @usei(%arg3) : (index) -> ()
// CHECK-NEXT:          %2 = func.call @get() : () -> i32
// CHECK-NEXT:          memref.store %2, %0[%arg3] : memref<?xi32>
// CHECK-NEXT:          %3 = "polygeist.subindex"(%1, %arg3) : (memref<?xi32>, index) -> memref<i32>
// CHECK-NEXT:          memref.store %2, %3[] : memref<i32>
// CHECK-NEXT:          scf.yield
// CHECK-NEXT:        }
// CHECK-NEXT:        scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:          %2 = memref.load %0[%arg3] : memref<?xi32>
// CHECK-NEXT:          %3 = "polygeist.subindex"(%1, %arg3) : (memref<?xi32>, index) -> memref<i32>
// CHECK-NEXT:          %4 = memref.load %3[] : memref<i32>
// CHECK-NEXT:          func.call @use(%4) : (i32) -> ()
// CHECK-NEXT:          func.call @use(%2) : (i32) -> ()
// CHECK-NEXT:          func.call @usei(%arg3) : (index) -> ()
// CHECK-NEXT:          scf.yield
// CHECK-NEXT:        }
// CHECK-NEXT:      }
// CHECK-NEXT:    } else {
// CHECK-NEXT:    }
// CHECK-NEXT:    return
// CHECK-NEXT:  }

// CHECK:  func.func @simple_if_hoist(%arg0: i1, %arg1: memref<i32>, %arg2: memref<i32>)
// CHECK-DAG:    %c0 = arith.constant 0 : index
// CHECK-DAG:    %c1 = arith.constant 1 : index
// CHECK-DAG:    %c9 = arith.constant 9 : index
// CHECK-NEXT:    scf.if %arg0 {
// CHECK-NEXT:      memref.alloca_scope  {
// CHECK-NEXT:        %0 = memref.alloca(%c9) : memref<?xi32>
// CHECK-NEXT:        %1 = memref.alloca(%c9) : memref<?xi32>
// CHECK-NEXT:        scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:          %2 = func.call @get() : () -> i32
// CHECK-NEXT:          memref.store %2, %0[%arg3] : memref<?xi32>
// CHECK-NEXT:          %3 = "polygeist.subindex"(%1, %arg3) : (memref<?xi32>, index) -> memref<i32>
// CHECK-NEXT:          memref.store %2, %3[] : memref<i32>
// CHECK-NEXT:          scf.yield
// CHECK-NEXT:        }
// CHECK-NEXT:        scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:          %2 = memref.load %0[%arg3] : memref<?xi32>
// CHECK-NEXT:          %3 = "polygeist.subindex"(%1, %arg3) : (memref<?xi32>, index) -> memref<i32>
// CHECK-NEXT:          %4 = memref.load %3[] : memref<i32>
// CHECK-NEXT:          func.call @use(%4) : (i32) -> ()
// CHECK-NEXT:          func.call @use(%2) : (i32) -> ()
// CHECK-NEXT:          scf.yield
// CHECK-NEXT:        }
// CHECK-NEXT:      }
// CHECK-NEXT:    } else {
// CHECK-NEXT:    }
// CHECK-NEXT:    return
// CHECK-NEXT:  }

// CHECK:  func.func @simple_if_split_i32(%arg0: i1, %arg1: memref<i32>, %arg2: memref<i32>)
// CHECK-DAG:    %c0 = arith.constant 0 : index
// CHECK-DAG:    %c1 = arith.constant 1 : index
// CHECK-DAG:    %c9 = arith.constant 9 : index
// CHECK-NEXT:    call @usei(%c0) : (index) -> ()
// CHECK-NEXT:    scf.if %arg0 {
// CHECK-NEXT:      memref.alloca_scope  {
// CHECK-NEXT:        %0 = memref.alloca(%c9) : memref<?xi32>
// CHECK-NEXT:        %1 = memref.alloca(%c9) : memref<?xi32>
// CHECK-NEXT:        scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:          func.call @usei(%arg3) : (index) -> ()
// CHECK-NEXT:          %2 = func.call @get() : () -> i32
// CHECK-NEXT:          memref.store %2, %0[%arg3] : memref<?xi32>
// CHECK-NEXT:          scf.yield
// CHECK-NEXT:        }
// CHECK-NEXT:        scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:          %2 = memref.load %0[%arg3] : memref<?xi32>
// CHECK-NEXT:          func.call @use(%2) : (i32) -> ()
// CHECK-NEXT:          %3 = "polygeist.subindex"(%1, %arg3) : (memref<?xi32>, index) -> memref<i32>
// CHECK-NEXT:          memref.store %2, %3[] : memref<i32>
// CHECK-NEXT:          %4 = "polygeist.subindex"(%1, %arg3) : (memref<?xi32>, index) -> memref<i32>
// CHECK-NEXT:          %5 = memref.load %4[] : memref<i32>
// CHECK-NEXT:          func.call @use(%5) : (i32) -> ()
// CHECK-NEXT:          scf.yield
// CHECK-NEXT:        }
// CHECK-NEXT:      }
// CHECK-NEXT:    } else {
// CHECK-NEXT:      scf.parallel (%arg3) = (%c0) to (%c9) step (%c1) {
// CHECK-NEXT:        func.call @usei(%arg3) : (index) -> ()
// CHECK-NEXT:        %0 = memref.alloca() : memref<i32>
// CHECK-NEXT:        %1 = func.call @get2() : () -> i32
// CHECK-NEXT:        func.call @use(%1) : (i32) -> ()
// CHECK-NEXT:        memref.store %1, %0[] : memref<i32>
// CHECK-NEXT:        %2 = memref.load %0[] : memref<i32>
// CHECK-NEXT:        func.call @use(%2) : (i32) -> ()
// CHECK-NEXT:        scf.yield
// CHECK-NEXT:      }
// CHECK-NEXT:    }
// CHECK-NEXT:    return
// CHECK-NEXT:  }
