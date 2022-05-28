# RxResource

This package includes a `Resource` generic type that makes it easier to wrap objects for use with the `Observable.using(_:observableFactory:)` operator. It also includes several samples.

The Scene.swift file contains resources designed to present/dismiss, or push/pop, view controllers.

The Cycle.swift file treats a `PublishSubject` as a resource to handle feedback loops.

The Examples folder contains other resource types that I've created. If you use the package to make your own resource, please send a pull request with examples you have made!

Check out [my article](https://danielt1263.medium.com/dealing-with-resources-in-rxswift-cd149d2322f4) to learn more.
