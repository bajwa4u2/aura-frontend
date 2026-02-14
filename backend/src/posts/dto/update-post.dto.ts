import { IsOptional, IsString, MaxLength } from 'class-validator'

export class UpdatePostDto {
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  text?: string
}
