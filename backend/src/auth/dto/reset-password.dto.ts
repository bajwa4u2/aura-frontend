import { IsString, MinLength, MaxLength } from 'class-validator'

export class ResetPasswordDto {
  @IsString()
  @MinLength(20)
  @MaxLength(200)
  token!: string

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  newPassword!: string
}
