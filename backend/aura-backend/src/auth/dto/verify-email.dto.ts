import { IsString, MinLength, MaxLength } from 'class-validator'

export class VerifyEmailDto {
  @IsString()
  @MinLength(20)
  @MaxLength(200)
  token!: string
}
