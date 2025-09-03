def addSTTOptions(parser):
    parser.add_argument(
        "--enable-stt",
        default=None,
        action="store_true",
        help="Whether to enable STT.",
    )

    parser.add_argument(
        "--impede-uop",
        default=None,
        action="store_true",
        help="Whether to use impede UOP.",
    )

    parser.add_argument(
        "--enable-delay-acc",
        default=None,
        action="store_true",
        help="Whether to enable Delayed Access.",
    )

    parser.add_argument(
        "--enable-delay-exec",
        default=None,
        action="store_true",
        help="Whether to enable Delayed Execution.",
    )

    parser.add_argument(
        "--spec-epoch",
        default=None,
        action="store_true",
        help="Whether to use speculation epoch.",
    )

    parser.add_argument(
        "--delay-reso",
        default=None,
        action="store_true",
        help="Whether to add delay resolution for the branch instructions.",
    )

    parser.add_argument(
        "--futuristic-threat-model",
        action="store_true",
        help="Whether to use the futuristic threat model or the "
        "spectre threat model",
    )

    parser.add_argument(
        "--wb-width",
        type=int,
        default=8,
        help="Writeback width",
    )

    parser.add_argument(
        "--decoder-width",
        type=int,
        default=8,
        help="Decoder width",
    )

    parser.add_argument(
        "--fu",
        type=int,
        default=6,
        help="Number of functional units"
    )

    parser.add_argument(
        "--iq-size",
        type=int,
        default=120,
        help="Instruction queue size",
    )

    parser.add_argument(
        "--print-taint-prop",
        action="store_true",
        help="Whether to print taint propagation information",
    )

    parser.add_argument(
        "--print-rob",
        action="store_true",
        help="Whether to print ROB information",
    )

    parser.add_argument(
        "--print-DelayInst",
        action="store_true",
        help="Whether to print delay instruction information",
    )
