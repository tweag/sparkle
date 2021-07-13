{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module Main where

-- import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
-- import Control.Monad
import Data.IORef
-- import qualified Data.Text as Text
-- import Data.Text (Text)


{-
f1 :: Text -> Bool
f1 s = "a" `Text.isInfixOf` s

f2 :: Text -> Bool
f2 s = "b" `Text.isInfixOf` s
-}

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "It's time for some memory memery"
    confSet conf "spark.hadoop.fs.s3a.aws.credentials.provider"
                 "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider"
    confSet conf "driver-memory" "1K"
    -- confSet conf "executor-memory" ""
    sc   <- getOrCreateSparkContext conf
    -- This S3 bucket is located in US East.
    rdd  <- textFile sc "s3a://tweag-sparkle/lorem-ipsum.txt"
    x1 <- RDD.first rdd
    x2 <- RDD.first rdd
    x3 <- RDD.first rdd
    x4 <- RDD.first rdd
    x5 <- RDD.first rdd
    x6 <- RDD.first rdd
    x7 <- RDD.first rdd
    x8 <- RDD.first rdd
    x9 <- RDD.first rdd
    x10 <- RDD.first rdd
    x11 <- RDD.first rdd
    x12 <- RDD.first rdd
    x13 <- RDD.first rdd
    x14 <- RDD.first rdd
    x15 <- RDD.first rdd
    x16 <- RDD.first rdd
    x17 <- RDD.first rdd
    x18 <- RDD.first rdd
    x19 <- RDD.first rdd
    x20 <- RDD.first rdd
    x21 <- RDD.first rdd
    x22 <- RDD.first rdd
    x23 <- RDD.first rdd
    x24 <- RDD.first rdd
    x25 <- RDD.first rdd
    x26 <- RDD.first rdd
    x27 <- RDD.first rdd
    x28 <- RDD.first rdd
    x29 <- RDD.first rdd
    x30 <- RDD.first rdd
    x31 <- RDD.first rdd
    x32 <- RDD.first rdd
    x33 <- RDD.first rdd
    x34 <- RDD.first rdd
    x35 <- RDD.first rdd
    x36 <- RDD.first rdd
    x37 <- RDD.first rdd
    x38 <- RDD.first rdd
    x39 <- RDD.first rdd
    x40 <- RDD.first rdd
    x41 <- RDD.first rdd
    x42 <- RDD.first rdd
    x43 <- RDD.first rdd
    x44 <- RDD.first rdd
    x45 <- RDD.first rdd
    x46 <- RDD.first rdd
    x47 <- RDD.first rdd
    x48 <- RDD.first rdd
    x49 <- RDD.first rdd
    x50 <- RDD.first rdd
    x51 <- RDD.first rdd
    x52 <- RDD.first rdd
    x53 <- RDD.first rdd
    x54 <- RDD.first rdd
    x55 <- RDD.first rdd
    x56 <- RDD.first rdd
    x57 <- RDD.first rdd
    x58 <- RDD.first rdd
    x59 <- RDD.first rdd
    x60 <- RDD.first rdd
    x61 <- RDD.first rdd
    x62 <- RDD.first rdd
    x63 <- RDD.first rdd
    x64 <- RDD.first rdd
    x65 <- RDD.first rdd
    x66 <- RDD.first rdd
    x67 <- RDD.first rdd
    x68 <- RDD.first rdd
    x69 <- RDD.first rdd
    x70 <- RDD.first rdd
    x71 <- RDD.first rdd
    x72 <- RDD.first rdd
    x73 <- RDD.first rdd
    x74 <- RDD.first rdd
    x75 <- RDD.first rdd
    x76 <- RDD.first rdd
    x77 <- RDD.first rdd
    x78 <- RDD.first rdd
    x79 <- RDD.first rdd
    x80 <- RDD.first rdd
    x81 <- RDD.first rdd
    x82 <- RDD.first rdd
    x83 <- RDD.first rdd
    x84 <- RDD.first rdd
    x85 <- RDD.first rdd
    x86 <- RDD.first rdd
    x87 <- RDD.first rdd
    x88 <- RDD.first rdd
    x89 <- RDD.first rdd
    x90 <- RDD.first rdd
    x91 <- RDD.first rdd
    x92 <- RDD.first rdd
    x93 <- RDD.first rdd
    x94 <- RDD.first rdd
    x95 <- RDD.first rdd
    x96 <- RDD.first rdd
    x97 <- RDD.first rdd
    x98 <- RDD.first rdd
    x99 <- RDD.first rdd
    x100 <- RDD.first rdd
    x101 <- RDD.first rdd
    x102 <- RDD.first rdd
    x103 <- RDD.first rdd
    x104 <- RDD.first rdd
    x105 <- RDD.first rdd
    x106 <- RDD.first rdd
    x107 <- RDD.first rdd
    x108 <- RDD.first rdd
    x109 <- RDD.first rdd
    x110 <- RDD.first rdd
    x111 <- RDD.first rdd
    x112 <- RDD.first rdd
    x113 <- RDD.first rdd
    x114 <- RDD.first rdd
    x115 <- RDD.first rdd
    x116 <- RDD.first rdd
    x117 <- RDD.first rdd
    x118 <- RDD.first rdd
    x119 <- RDD.first rdd
    x120 <- RDD.first rdd
    x121 <- RDD.first rdd
    x122 <- RDD.first rdd
    x123 <- RDD.first rdd
    x124 <- RDD.first rdd
    x125 <- RDD.first rdd
    x126 <- RDD.first rdd
    x127 <- RDD.first rdd
    x128 <- RDD.first rdd
    x129 <- RDD.first rdd
    x130 <- RDD.first rdd
    x131 <- RDD.first rdd
    x132 <- RDD.first rdd
    x133 <- RDD.first rdd
    x134 <- RDD.first rdd
    x135 <- RDD.first rdd
    x136 <- RDD.first rdd
    x137 <- RDD.first rdd
    x138 <- RDD.first rdd
    x139 <- RDD.first rdd
    x140 <- RDD.first rdd
    x141 <- RDD.first rdd
    x142 <- RDD.first rdd
    x143 <- RDD.first rdd
    x144 <- RDD.first rdd
    x145 <- RDD.first rdd
    x146 <- RDD.first rdd
    x147 <- RDD.first rdd
    x148 <- RDD.first rdd
    x149 <- RDD.first rdd
    x150 <- RDD.first rdd
    x151 <- RDD.first rdd
    x152 <- RDD.first rdd
    x153 <- RDD.first rdd
    x154 <- RDD.first rdd
    x155 <- RDD.first rdd
    x156 <- RDD.first rdd
    x157 <- RDD.first rdd
    x158 <- RDD.first rdd
    x159 <- RDD.first rdd
    x160 <- RDD.first rdd
    x161 <- RDD.first rdd
    x162 <- RDD.first rdd
    x163 <- RDD.first rdd
    x164 <- RDD.first rdd
    x165 <- RDD.first rdd
    x166 <- RDD.first rdd
    x167 <- RDD.first rdd
    x168 <- RDD.first rdd
    x169 <- RDD.first rdd
    x170 <- RDD.first rdd
    x171 <- RDD.first rdd
    x172 <- RDD.first rdd
    x173 <- RDD.first rdd
    x174 <- RDD.first rdd
    x175 <- RDD.first rdd
    x176 <- RDD.first rdd
    x177 <- RDD.first rdd
    x178 <- RDD.first rdd
    x179 <- RDD.first rdd
    x180 <- RDD.first rdd
    x181 <- RDD.first rdd
    x182 <- RDD.first rdd
    x183 <- RDD.first rdd
    x184 <- RDD.first rdd
    x185 <- RDD.first rdd
    x186 <- RDD.first rdd
    x187 <- RDD.first rdd
    x188 <- RDD.first rdd
    x189 <- RDD.first rdd
    x190 <- RDD.first rdd
    x191 <- RDD.first rdd
    x192 <- RDD.first rdd
    x193 <- RDD.first rdd
    x194 <- RDD.first rdd
    x195 <- RDD.first rdd
    x196 <- RDD.first rdd
    x197 <- RDD.first rdd
    x198 <- RDD.first rdd
    x199 <- RDD.first rdd
    x200 <- RDD.first rdd
    x201 <- RDD.first rdd
    x202 <- RDD.first rdd
    x203 <- RDD.first rdd
    x204 <- RDD.first rdd
    x205 <- RDD.first rdd
    x206 <- RDD.first rdd
    x207 <- RDD.first rdd
    x208 <- RDD.first rdd
    x209 <- RDD.first rdd
    x210 <- RDD.first rdd
    x211 <- RDD.first rdd
    x212 <- RDD.first rdd
    x213 <- RDD.first rdd
    x214 <- RDD.first rdd
    x215 <- RDD.first rdd
    x216 <- RDD.first rdd
    x217 <- RDD.first rdd
    x218 <- RDD.first rdd
    x219 <- RDD.first rdd
    x220 <- RDD.first rdd
    x221 <- RDD.first rdd
    x222 <- RDD.first rdd
    x223 <- RDD.first rdd
    x224 <- RDD.first rdd
    x225 <- RDD.first rdd
    x226 <- RDD.first rdd
    x227 <- RDD.first rdd
    x228 <- RDD.first rdd
    x229 <- RDD.first rdd
    x230 <- RDD.first rdd
    x231 <- RDD.first rdd
    x232 <- RDD.first rdd
    x233 <- RDD.first rdd
    x234 <- RDD.first rdd
    x235 <- RDD.first rdd
    x236 <- RDD.first rdd
    x237 <- RDD.first rdd
    x238 <- RDD.first rdd
    x239 <- RDD.first rdd
    x240 <- RDD.first rdd
    x241 <- RDD.first rdd
    x242 <- RDD.first rdd
    x243 <- RDD.first rdd
    x244 <- RDD.first rdd
    x245 <- RDD.first rdd
    x246 <- RDD.first rdd
    x247 <- RDD.first rdd
    x248 <- RDD.first rdd
    x249 <- RDD.first rdd
    x250 <- RDD.first rdd
    x251 <- RDD.first rdd
    x252 <- RDD.first rdd
    x253 <- RDD.first rdd
    x254 <- RDD.first rdd
    x255 <- RDD.first rdd
    x256 <- RDD.first rdd
    x257 <- RDD.first rdd
    x258 <- RDD.first rdd
    x259 <- RDD.first rdd
    x260 <- RDD.first rdd
    x261 <- RDD.first rdd
    x262 <- RDD.first rdd
    x263 <- RDD.first rdd
    x264 <- RDD.first rdd
    x265 <- RDD.first rdd
    x266 <- RDD.first rdd
    x267 <- RDD.first rdd
    x268 <- RDD.first rdd
    x269 <- RDD.first rdd
    x270 <- RDD.first rdd
    x271 <- RDD.first rdd
    x272 <- RDD.first rdd
    x273 <- RDD.first rdd
    x274 <- RDD.first rdd
    x275 <- RDD.first rdd
    x276 <- RDD.first rdd
    x277 <- RDD.first rdd
    x278 <- RDD.first rdd
    x279 <- RDD.first rdd
    x280 <- RDD.first rdd
    x281 <- RDD.first rdd
    x282 <- RDD.first rdd
    x283 <- RDD.first rdd
    x284 <- RDD.first rdd
    x285 <- RDD.first rdd
    x286 <- RDD.first rdd
    x287 <- RDD.first rdd
    x288 <- RDD.first rdd
    x289 <- RDD.first rdd
    x290 <- RDD.first rdd
    x291 <- RDD.first rdd
    x292 <- RDD.first rdd
    x293 <- RDD.first rdd
    x294 <- RDD.first rdd
    x295 <- RDD.first rdd
    x296 <- RDD.first rdd
    x297 <- RDD.first rdd
    x298 <- RDD.first rdd
    x299 <- RDD.first rdd
    x300 <- RDD.first rdd
    x301 <- RDD.first rdd
    x302 <- RDD.first rdd
    x303 <- RDD.first rdd
    x304 <- RDD.first rdd
    x305 <- RDD.first rdd
    x306 <- RDD.first rdd
    x307 <- RDD.first rdd
    x308 <- RDD.first rdd
    x309 <- RDD.first rdd
    x310 <- RDD.first rdd
    x311 <- RDD.first rdd
    x312 <- RDD.first rdd
    x313 <- RDD.first rdd
    x314 <- RDD.first rdd
    x315 <- RDD.first rdd
    x316 <- RDD.first rdd
    x317 <- RDD.first rdd
    x318 <- RDD.first rdd
    x319 <- RDD.first rdd
    x320 <- RDD.first rdd
    x321 <- RDD.first rdd
    x322 <- RDD.first rdd
    x323 <- RDD.first rdd
    x324 <- RDD.first rdd
    x325 <- RDD.first rdd
    x326 <- RDD.first rdd
    x327 <- RDD.first rdd
    x328 <- RDD.first rdd
    x329 <- RDD.first rdd
    x330 <- RDD.first rdd
    x331 <- RDD.first rdd
    x332 <- RDD.first rdd
    x333 <- RDD.first rdd
    x334 <- RDD.first rdd
    x335 <- RDD.first rdd
    x336 <- RDD.first rdd
    x337 <- RDD.first rdd
    x338 <- RDD.first rdd
    x339 <- RDD.first rdd
    x340 <- RDD.first rdd
    x341 <- RDD.first rdd
    x342 <- RDD.first rdd
    x343 <- RDD.first rdd
    x344 <- RDD.first rdd
    x345 <- RDD.first rdd
    x346 <- RDD.first rdd
    x347 <- RDD.first rdd
    x348 <- RDD.first rdd
    x349 <- RDD.first rdd
    x350 <- RDD.first rdd
    x351 <- RDD.first rdd
    x352 <- RDD.first rdd
    x353 <- RDD.first rdd
    x354 <- RDD.first rdd
    x355 <- RDD.first rdd
    x356 <- RDD.first rdd
    x357 <- RDD.first rdd
    x358 <- RDD.first rdd
    x359 <- RDD.first rdd
    x360 <- RDD.first rdd
    x361 <- RDD.first rdd
    x362 <- RDD.first rdd
    x363 <- RDD.first rdd
    x364 <- RDD.first rdd
    x365 <- RDD.first rdd
    x366 <- RDD.first rdd
    x367 <- RDD.first rdd
    x368 <- RDD.first rdd
    x369 <- RDD.first rdd
    x370 <- RDD.first rdd
    x371 <- RDD.first rdd
    x372 <- RDD.first rdd
    x373 <- RDD.first rdd
    x374 <- RDD.first rdd
    x375 <- RDD.first rdd
    x376 <- RDD.first rdd
    x377 <- RDD.first rdd
    x378 <- RDD.first rdd
    x379 <- RDD.first rdd
    x380 <- RDD.first rdd
    x381 <- RDD.first rdd
    x382 <- RDD.first rdd
    x383 <- RDD.first rdd
    x384 <- RDD.first rdd
    x385 <- RDD.first rdd
    x386 <- RDD.first rdd
    x387 <- RDD.first rdd
    x388 <- RDD.first rdd
    x389 <- RDD.first rdd
    x390 <- RDD.first rdd
    x391 <- RDD.first rdd
    x392 <- RDD.first rdd
    x393 <- RDD.first rdd
    x394 <- RDD.first rdd
    x395 <- RDD.first rdd
    x396 <- RDD.first rdd
    x397 <- RDD.first rdd
    x398 <- RDD.first rdd
    x399 <- RDD.first rdd
    x400 <- RDD.first rdd
    x401 <- RDD.first rdd
    x402 <- RDD.first rdd
    x403 <- RDD.first rdd
    x404 <- RDD.first rdd
    x405 <- RDD.first rdd
    x406 <- RDD.first rdd
    x407 <- RDD.first rdd
    x408 <- RDD.first rdd
    x409 <- RDD.first rdd
    x410 <- RDD.first rdd
    x411 <- RDD.first rdd
    x412 <- RDD.first rdd
    x413 <- RDD.first rdd
    x414 <- RDD.first rdd
    x415 <- RDD.first rdd
    x416 <- RDD.first rdd
    x417 <- RDD.first rdd
    x418 <- RDD.first rdd
    x419 <- RDD.first rdd
    x420 <- RDD.first rdd
    x421 <- RDD.first rdd
    x422 <- RDD.first rdd
    x423 <- RDD.first rdd
    x424 <- RDD.first rdd
    x425 <- RDD.first rdd
    x426 <- RDD.first rdd
    x427 <- RDD.first rdd
    x428 <- RDD.first rdd
    x429 <- RDD.first rdd
    x430 <- RDD.first rdd
    x431 <- RDD.first rdd
    x432 <- RDD.first rdd
    x433 <- RDD.first rdd
    x434 <- RDD.first rdd
    x435 <- RDD.first rdd
    x436 <- RDD.first rdd
    x437 <- RDD.first rdd
    x438 <- RDD.first rdd
    x439 <- RDD.first rdd
    x440 <- RDD.first rdd
    x441 <- RDD.first rdd
    x442 <- RDD.first rdd
    x443 <- RDD.first rdd
    x444 <- RDD.first rdd
    x445 <- RDD.first rdd
    x446 <- RDD.first rdd
    x447 <- RDD.first rdd
    x448 <- RDD.first rdd
    x449 <- RDD.first rdd
    x450 <- RDD.first rdd
    x451 <- RDD.first rdd
    x452 <- RDD.first rdd
    x453 <- RDD.first rdd
    x454 <- RDD.first rdd
    x455 <- RDD.first rdd
    x456 <- RDD.first rdd
    x457 <- RDD.first rdd
    x458 <- RDD.first rdd
    x459 <- RDD.first rdd
    x460 <- RDD.first rdd
    x461 <- RDD.first rdd
    x462 <- RDD.first rdd
    x463 <- RDD.first rdd
    x464 <- RDD.first rdd
    x465 <- RDD.first rdd
    x466 <- RDD.first rdd
    x467 <- RDD.first rdd
    x468 <- RDD.first rdd
    x469 <- RDD.first rdd
    x470 <- RDD.first rdd
    x471 <- RDD.first rdd
    x472 <- RDD.first rdd
    x473 <- RDD.first rdd
    x474 <- RDD.first rdd
    x475 <- RDD.first rdd
    x476 <- RDD.first rdd
    x477 <- RDD.first rdd
    x478 <- RDD.first rdd
    x479 <- RDD.first rdd
    x480 <- RDD.first rdd
    x481 <- RDD.first rdd
    x482 <- RDD.first rdd
    x483 <- RDD.first rdd
    x484 <- RDD.first rdd
    x485 <- RDD.first rdd
    x486 <- RDD.first rdd
    x487 <- RDD.first rdd
    x488 <- RDD.first rdd
    x489 <- RDD.first rdd
    x490 <- RDD.first rdd
    x491 <- RDD.first rdd
    x492 <- RDD.first rdd
    x493 <- RDD.first rdd
    x494 <- RDD.first rdd
    x495 <- RDD.first rdd
    x496 <- RDD.first rdd
    x497 <- RDD.first rdd
    x498 <- RDD.first rdd
    x499 <- RDD.first rdd
    x500 <- RDD.first rdd
    x501 <- RDD.first rdd
    x502 <- RDD.first rdd
    x503 <- RDD.first rdd
    x504 <- RDD.first rdd
    x505 <- RDD.first rdd
    x506 <- RDD.first rdd
    x507 <- RDD.first rdd
    x508 <- RDD.first rdd
    x509 <- RDD.first rdd
    x510 <- RDD.first rdd
    x511 <- RDD.first rdd
    x512 <- RDD.first rdd
    x513 <- RDD.first rdd
    x514 <- RDD.first rdd
    x515 <- RDD.first rdd
    x516 <- RDD.first rdd
    x517 <- RDD.first rdd
    x518 <- RDD.first rdd
    x519 <- RDD.first rdd
    x520 <- RDD.first rdd
    x521 <- RDD.first rdd
    x522 <- RDD.first rdd
    x523 <- RDD.first rdd
    x524 <- RDD.first rdd
    x525 <- RDD.first rdd
    x526 <- RDD.first rdd
    x527 <- RDD.first rdd
    x528 <- RDD.first rdd
    x529 <- RDD.first rdd
    x530 <- RDD.first rdd
    x531 <- RDD.first rdd
    x532 <- RDD.first rdd
    x533 <- RDD.first rdd
    x534 <- RDD.first rdd
    x535 <- RDD.first rdd
    x536 <- RDD.first rdd
    x537 <- RDD.first rdd
    x538 <- RDD.first rdd
    x539 <- RDD.first rdd
    x540 <- RDD.first rdd
    x541 <- RDD.first rdd
    x542 <- RDD.first rdd
    x543 <- RDD.first rdd
    x544 <- RDD.first rdd
    x545 <- RDD.first rdd
    x546 <- RDD.first rdd
    x547 <- RDD.first rdd
    x548 <- RDD.first rdd
    x549 <- RDD.first rdd
    x550 <- RDD.first rdd
    x551 <- RDD.first rdd
    x552 <- RDD.first rdd
    x553 <- RDD.first rdd
    x554 <- RDD.first rdd
    x555 <- RDD.first rdd
    x556 <- RDD.first rdd
    x557 <- RDD.first rdd
    x558 <- RDD.first rdd
    x559 <- RDD.first rdd
    x560 <- RDD.first rdd
    x561 <- RDD.first rdd
    x562 <- RDD.first rdd
    x563 <- RDD.first rdd
    x564 <- RDD.first rdd
    x565 <- RDD.first rdd
    x566 <- RDD.first rdd
    x567 <- RDD.first rdd
    x568 <- RDD.first rdd
    x569 <- RDD.first rdd
    x570 <- RDD.first rdd
    x571 <- RDD.first rdd
    x572 <- RDD.first rdd
    x573 <- RDD.first rdd
    x574 <- RDD.first rdd
    x575 <- RDD.first rdd

    ior <- newIORef "hi"
    writeIORef ior x1
    writeIORef ior x2
    writeIORef ior x3
    writeIORef ior x4
    writeIORef ior x5
    writeIORef ior x6
    writeIORef ior x7
    writeIORef ior x8
    writeIORef ior x9
    writeIORef ior x10
    writeIORef ior x11
    writeIORef ior x12
    writeIORef ior x13
    writeIORef ior x14
    writeIORef ior x15
    writeIORef ior x16
    writeIORef ior x17
    writeIORef ior x18
    writeIORef ior x19
    writeIORef ior x20
    writeIORef ior x21
    writeIORef ior x22
    writeIORef ior x23
    writeIORef ior x24
    writeIORef ior x25
    writeIORef ior x26
    writeIORef ior x27
    writeIORef ior x28
    writeIORef ior x29
    writeIORef ior x30
    writeIORef ior x31
    writeIORef ior x32
    writeIORef ior x33
    writeIORef ior x34
    writeIORef ior x35
    writeIORef ior x36
    writeIORef ior x37
    writeIORef ior x38
    writeIORef ior x39
    writeIORef ior x40
    writeIORef ior x41
    writeIORef ior x42
    writeIORef ior x43
    writeIORef ior x44
    writeIORef ior x45
    writeIORef ior x46
    writeIORef ior x47
    writeIORef ior x48
    writeIORef ior x49
    writeIORef ior x50
    writeIORef ior x51
    writeIORef ior x52
    writeIORef ior x53
    writeIORef ior x54
    writeIORef ior x55
    writeIORef ior x56
    writeIORef ior x57
    writeIORef ior x58
    writeIORef ior x59
    writeIORef ior x60
    writeIORef ior x61
    writeIORef ior x62
    writeIORef ior x63
    writeIORef ior x64
    writeIORef ior x65
    writeIORef ior x66
    writeIORef ior x67
    writeIORef ior x68
    writeIORef ior x69
    writeIORef ior x70
    writeIORef ior x71
    writeIORef ior x72
    writeIORef ior x73
    writeIORef ior x74
    writeIORef ior x75
    writeIORef ior x76
    writeIORef ior x77
    writeIORef ior x78
    writeIORef ior x79
    writeIORef ior x80
    writeIORef ior x81
    writeIORef ior x82
    writeIORef ior x83
    writeIORef ior x84
    writeIORef ior x85
    writeIORef ior x86
    writeIORef ior x87
    writeIORef ior x88
    writeIORef ior x89
    writeIORef ior x90
    writeIORef ior x91
    writeIORef ior x92
    writeIORef ior x93
    writeIORef ior x94
    writeIORef ior x95
    writeIORef ior x96
    writeIORef ior x97
    writeIORef ior x98
    writeIORef ior x99
    writeIORef ior x100
    writeIORef ior x101
    writeIORef ior x102
    writeIORef ior x103
    writeIORef ior x104
    writeIORef ior x105
    writeIORef ior x106
    writeIORef ior x107
    writeIORef ior x108
    writeIORef ior x109
    writeIORef ior x110
    writeIORef ior x111
    writeIORef ior x112
    writeIORef ior x113
    writeIORef ior x114
    writeIORef ior x115
    writeIORef ior x116
    writeIORef ior x117
    writeIORef ior x118
    writeIORef ior x119
    writeIORef ior x120
    writeIORef ior x121
    writeIORef ior x122
    writeIORef ior x123
    writeIORef ior x124
    writeIORef ior x125
    writeIORef ior x126
    writeIORef ior x127
    writeIORef ior x128
    writeIORef ior x129
    writeIORef ior x130
    writeIORef ior x131
    writeIORef ior x132
    writeIORef ior x133
    writeIORef ior x134
    writeIORef ior x135
    writeIORef ior x136
    writeIORef ior x137
    writeIORef ior x138
    writeIORef ior x139
    writeIORef ior x140
    writeIORef ior x141
    writeIORef ior x142
    writeIORef ior x143
    writeIORef ior x144
    writeIORef ior x145
    writeIORef ior x146
    writeIORef ior x147
    writeIORef ior x148
    writeIORef ior x149
    writeIORef ior x150
    writeIORef ior x151
    writeIORef ior x152
    writeIORef ior x153
    writeIORef ior x154
    writeIORef ior x155
    writeIORef ior x156
    writeIORef ior x157
    writeIORef ior x158
    writeIORef ior x159
    writeIORef ior x160
    writeIORef ior x161
    writeIORef ior x162
    writeIORef ior x163
    writeIORef ior x164
    writeIORef ior x165
    writeIORef ior x166
    writeIORef ior x167
    writeIORef ior x168
    writeIORef ior x169
    writeIORef ior x170
    writeIORef ior x171
    writeIORef ior x172
    writeIORef ior x173
    writeIORef ior x174
    writeIORef ior x175
    writeIORef ior x176
    writeIORef ior x177
    writeIORef ior x178
    writeIORef ior x179
    writeIORef ior x180
    writeIORef ior x181
    writeIORef ior x182
    writeIORef ior x183
    writeIORef ior x184
    writeIORef ior x185
    writeIORef ior x186
    writeIORef ior x187
    writeIORef ior x188
    writeIORef ior x189
    writeIORef ior x190
    writeIORef ior x191
    writeIORef ior x192
    writeIORef ior x193
    writeIORef ior x194
    writeIORef ior x195
    writeIORef ior x196
    writeIORef ior x197
    writeIORef ior x198
    writeIORef ior x199
    writeIORef ior x200
    writeIORef ior x201
    writeIORef ior x202
    writeIORef ior x203
    writeIORef ior x204
    writeIORef ior x205
    writeIORef ior x206
    writeIORef ior x207
    writeIORef ior x208
    writeIORef ior x209
    writeIORef ior x210
    writeIORef ior x211
    writeIORef ior x212
    writeIORef ior x213
    writeIORef ior x214
    writeIORef ior x215
    writeIORef ior x216
    writeIORef ior x217
    writeIORef ior x218
    writeIORef ior x219
    writeIORef ior x220
    writeIORef ior x221
    writeIORef ior x222
    writeIORef ior x223
    writeIORef ior x224
    writeIORef ior x225
    writeIORef ior x226
    writeIORef ior x227
    writeIORef ior x228
    writeIORef ior x229
    writeIORef ior x230
    writeIORef ior x231
    writeIORef ior x232
    writeIORef ior x233
    writeIORef ior x234
    writeIORef ior x235
    writeIORef ior x236
    writeIORef ior x237
    writeIORef ior x238
    writeIORef ior x239
    writeIORef ior x240
    writeIORef ior x241
    writeIORef ior x242
    writeIORef ior x243
    writeIORef ior x244
    writeIORef ior x245
    writeIORef ior x246
    writeIORef ior x247
    writeIORef ior x248
    writeIORef ior x249
    writeIORef ior x250
    writeIORef ior x251
    writeIORef ior x252
    writeIORef ior x253
    writeIORef ior x254
    writeIORef ior x255
    writeIORef ior x256
    writeIORef ior x257
    writeIORef ior x258
    writeIORef ior x259
    writeIORef ior x260
    writeIORef ior x261
    writeIORef ior x262
    writeIORef ior x263
    writeIORef ior x264
    writeIORef ior x265
    writeIORef ior x266
    writeIORef ior x267
    writeIORef ior x268
    writeIORef ior x269
    writeIORef ior x270
    writeIORef ior x271
    writeIORef ior x272
    writeIORef ior x273
    writeIORef ior x274
    writeIORef ior x275
    writeIORef ior x276
    writeIORef ior x277
    writeIORef ior x278
    writeIORef ior x279
    writeIORef ior x280
    writeIORef ior x281
    writeIORef ior x282
    writeIORef ior x283
    writeIORef ior x284
    writeIORef ior x285
    writeIORef ior x286
    writeIORef ior x287
    writeIORef ior x288
    writeIORef ior x289
    writeIORef ior x290
    writeIORef ior x291
    writeIORef ior x292
    writeIORef ior x293
    writeIORef ior x294
    writeIORef ior x295
    writeIORef ior x296
    writeIORef ior x297
    writeIORef ior x298
    writeIORef ior x299
    writeIORef ior x300
    writeIORef ior x301
    writeIORef ior x302
    writeIORef ior x303
    writeIORef ior x304
    writeIORef ior x305
    writeIORef ior x306
    writeIORef ior x307
    writeIORef ior x308
    writeIORef ior x309
    writeIORef ior x310
    writeIORef ior x311
    writeIORef ior x312
    writeIORef ior x313
    writeIORef ior x314
    writeIORef ior x315
    writeIORef ior x316
    writeIORef ior x317
    writeIORef ior x318
    writeIORef ior x319
    writeIORef ior x320
    writeIORef ior x321
    writeIORef ior x322
    writeIORef ior x323
    writeIORef ior x324
    writeIORef ior x325
    writeIORef ior x326
    writeIORef ior x327
    writeIORef ior x328
    writeIORef ior x329
    writeIORef ior x330
    writeIORef ior x331
    writeIORef ior x332
    writeIORef ior x333
    writeIORef ior x334
    writeIORef ior x335
    writeIORef ior x336
    writeIORef ior x337
    writeIORef ior x338
    writeIORef ior x339
    writeIORef ior x340
    writeIORef ior x341
    writeIORef ior x342
    writeIORef ior x343
    writeIORef ior x344
    writeIORef ior x345
    writeIORef ior x346
    writeIORef ior x347
    writeIORef ior x348
    writeIORef ior x349
    writeIORef ior x350
    writeIORef ior x351
    writeIORef ior x352
    writeIORef ior x353
    writeIORef ior x354
    writeIORef ior x355
    writeIORef ior x356
    writeIORef ior x357
    writeIORef ior x358
    writeIORef ior x359
    writeIORef ior x360
    writeIORef ior x361
    writeIORef ior x362
    writeIORef ior x363
    writeIORef ior x364
    writeIORef ior x365
    writeIORef ior x366
    writeIORef ior x367
    writeIORef ior x368
    writeIORef ior x369
    writeIORef ior x370
    writeIORef ior x371
    writeIORef ior x372
    writeIORef ior x373
    writeIORef ior x374
    writeIORef ior x375
    writeIORef ior x376
    writeIORef ior x377
    writeIORef ior x378
    writeIORef ior x379
    writeIORef ior x380
    writeIORef ior x381
    writeIORef ior x382
    writeIORef ior x383
    writeIORef ior x384
    writeIORef ior x385
    writeIORef ior x386
    writeIORef ior x387
    writeIORef ior x388
    writeIORef ior x389
    writeIORef ior x390
    writeIORef ior x391
    writeIORef ior x392
    writeIORef ior x393
    writeIORef ior x394
    writeIORef ior x395
    writeIORef ior x396
    writeIORef ior x397
    writeIORef ior x398
    writeIORef ior x399
    writeIORef ior x400
    writeIORef ior x401
    writeIORef ior x402
    writeIORef ior x403
    writeIORef ior x404
    writeIORef ior x405
    writeIORef ior x406
    writeIORef ior x407
    writeIORef ior x408
    writeIORef ior x409
    writeIORef ior x410
    writeIORef ior x411
    writeIORef ior x412
    writeIORef ior x413
    writeIORef ior x414
    writeIORef ior x415
    writeIORef ior x416
    writeIORef ior x417
    writeIORef ior x418
    writeIORef ior x419
    writeIORef ior x420
    writeIORef ior x421
    writeIORef ior x422
    writeIORef ior x423
    writeIORef ior x424
    writeIORef ior x425
    writeIORef ior x426
    writeIORef ior x427
    writeIORef ior x428
    writeIORef ior x429
    writeIORef ior x430
    writeIORef ior x431
    writeIORef ior x432
    writeIORef ior x433
    writeIORef ior x434
    writeIORef ior x435
    writeIORef ior x436
    writeIORef ior x437
    writeIORef ior x438
    writeIORef ior x439
    writeIORef ior x440
    writeIORef ior x441
    writeIORef ior x442
    writeIORef ior x443
    writeIORef ior x444
    writeIORef ior x445
    writeIORef ior x446
    writeIORef ior x447
    writeIORef ior x448
    writeIORef ior x449
    writeIORef ior x450
    writeIORef ior x451
    writeIORef ior x452
    writeIORef ior x453
    writeIORef ior x454
    writeIORef ior x455
    writeIORef ior x456
    writeIORef ior x457
    writeIORef ior x458
    writeIORef ior x459
    writeIORef ior x460
    writeIORef ior x461
    writeIORef ior x462
    writeIORef ior x463
    writeIORef ior x464
    writeIORef ior x465
    writeIORef ior x466
    writeIORef ior x467
    writeIORef ior x468
    writeIORef ior x469
    writeIORef ior x470
    writeIORef ior x471
    writeIORef ior x472
    writeIORef ior x473
    writeIORef ior x474
    writeIORef ior x475
    writeIORef ior x476
    writeIORef ior x477
    writeIORef ior x478
    writeIORef ior x479
    writeIORef ior x480
    writeIORef ior x481
    writeIORef ior x482
    writeIORef ior x483
    writeIORef ior x484
    writeIORef ior x485
    writeIORef ior x486
    writeIORef ior x487
    writeIORef ior x488
    writeIORef ior x489
    writeIORef ior x490
    writeIORef ior x491
    writeIORef ior x492
    writeIORef ior x493
    writeIORef ior x494
    writeIORef ior x495
    writeIORef ior x496
    writeIORef ior x497
    writeIORef ior x498
    writeIORef ior x499
    writeIORef ior x500
    writeIORef ior x501
    writeIORef ior x502
    writeIORef ior x503
    writeIORef ior x504
    writeIORef ior x505
    writeIORef ior x506
    writeIORef ior x507
    writeIORef ior x508
    writeIORef ior x509
    writeIORef ior x510
    writeIORef ior x511
    writeIORef ior x512
    writeIORef ior x513
    writeIORef ior x514
    writeIORef ior x515
    writeIORef ior x516
    writeIORef ior x517
    writeIORef ior x518
    writeIORef ior x519
    writeIORef ior x520
    writeIORef ior x521
    writeIORef ior x522
    writeIORef ior x523
    writeIORef ior x524
    writeIORef ior x525
    writeIORef ior x526
    writeIORef ior x527
    writeIORef ior x528
    writeIORef ior x529
    writeIORef ior x530
    writeIORef ior x531
    writeIORef ior x532
    writeIORef ior x533
    writeIORef ior x534
    writeIORef ior x535
    writeIORef ior x536
    writeIORef ior x537
    writeIORef ior x538
    writeIORef ior x539
    writeIORef ior x540
    writeIORef ior x541
    writeIORef ior x542
    writeIORef ior x543
    writeIORef ior x544
    writeIORef ior x545
    writeIORef ior x546
    writeIORef ior x547
    writeIORef ior x548
    writeIORef ior x549
    writeIORef ior x550
    writeIORef ior x551
    writeIORef ior x552
    writeIORef ior x553
    writeIORef ior x554
    writeIORef ior x555
    writeIORef ior x556
    writeIORef ior x557
    writeIORef ior x558
    writeIORef ior x559
    writeIORef ior x560
    writeIORef ior x561
    writeIORef ior x562
    writeIORef ior x563
    writeIORef ior x564
    writeIORef ior x565
    writeIORef ior x566
    writeIORef ior x567
    writeIORef ior x568
    writeIORef ior x569
    writeIORef ior x570
    writeIORef ior x571
    writeIORef ior x572
    writeIORef ior x573
    writeIORef ior x574
    writeIORef ior x575
    {-
    ior  <- newIORef "hello"
    forM_ [0..250000 :: Int] $ \i -> do
      frst <- RDD.first rdd
      modifyIORef ior (<> (frst <> (Text.pack (show i))))
    -}
    --
{-
    len  <- RDD.count rdd 
    putStrLn $ show len ++ " lines total."
    xs   <- RDD.filter (closure (static f1)) rdd
    ys   <- RDD.filter (closure (static f2)) rdd
    pure (const () (xs, ys))
    -}
    {-
    numAs <- RDD.count xs
    numBs <- RDD.count ys
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."
            -}
