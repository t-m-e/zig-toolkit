pub const ObfuscationError = error{
    BufferError,
    BufferAlignmentError,
};

pub const BufferError = error{
    InitError,
    NoData,
};

pub const ElfError = error{
    InitError,
    AllocatorError,
    FileOpenError,
    FileSeekError,
    FileReadAllError,
    BufferError,
    NoHeader,
    NoSectionHeader,
    SectionHeaderError,
    NoSymbol,
};

pub const MonoBufError = error{
    InitError,
    SerializerFull,
    DeserializerEmpty,
    DeserializerNotEnough,
    DeserializerBufferCopyFailed,
};
