// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.example.android_hardware_smoke_test

import android.app.Activity
import android.os.Bundle

/** An opaque activity used to exercise a real stop/resume transition in instrumentation tests. */
class BackgroundActivity : Activity() {
    companion object {
        @Volatile var instance: BackgroundActivity? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
