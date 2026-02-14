import { IsEmail, IsOptional, IsString, MinLength, Matches, MaxLength } from 'class-validator'

export class RegisterDto {
  @IsEmail()
  email!: string

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password!: string

  @IsString()
  @MinLength(3)
  @MaxLength(24)
  @Matches(/^[a-z0-9_]+$/, { message: 'Handle must be lowercase letters, numbers, underscores only' })
  handle!: string

  @IsOptional()
  @IsString()
  @MaxLength(40)
  displayName?: string
}
